## 배포 순서

### 1. 변수 파일 작성

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 에서 최소 두 값을 채웁니다.

```hcl
# 접속할 공인 IP. curl -s https://checkip.amazonaws.com 로 확인
allowed_ssh_cidr = "1.2.3.4/32"

# Discord 채널 편집 → 연동 → 웹후크에서 생성. 비우면 알림 리소스를 만들지 않음
discord_webhook_url = "https://discord.com/api/webhooks/..."
```

`terraform.tfvars` 는 `.gitignore` 에 포함되어 커밋되지 않습니다.

### 2. 초기화

```bash
terraform init
```

### 3. apply — 두 단계로 실행

```bash
# 1단계: 네트워크와 클러스터 (약 10분)
terraform apply -target=module.vpc -target=module.eks

# 2단계: 나머지 전부 (약 5분)
terraform apply
```

**왜 나누는가** — `kubernetes` · `helm` 프로바이더는 클러스터 엔드포인트와 인증서를 받아
설정되는데, 이 값들은 같은 apply 안에서 생성되는 `module.eks` 의 출력입니다.
클러스터가 없는 첫 실행에서는 프로바이더 설정값이 확정되지 않아
`Provider configuration ... unknown value` 로 실패합니다.
클러스터를 먼저 만들어 두면 두 번째 apply에서는 값이 확정되어 정상 동작합니다.

**클러스터가 이미 있는 이후 실행부터는 `terraform apply` 한 번으로 충분합니다.**

> 근본적으로는 클러스터와 애드온을 별도 루트 모듈로 분리하는 것이 맞습니다.
> 이 레포는 규모가 작아 단일 루트 모듈로 두고 실행 순서로 해결했습니다.

### 4. kubeconfig 설정

```bash
aws eks update-kubeconfig --region ap-northeast-2 --name taskflow-cluster
```

### 5. 이미지 빌드

이 시점에는 ECR이 비어 있어 파드가 `ImagePullBackOff` 상태입니다.
**ALB와 HPA는 정상적으로 생성됩니다.**

각 레포지토리의 Actions 탭에서 워크플로우를 실행합니다.

- `taskflow-frontend` → Actions → **Deploy Frontend** → Run workflow
- `taskflow-backend` → Actions → **Deploy Backend** → Run workflow

워크플로우가 이미지를 `:커밋SHA` 와 `:latest` 두 태그로 push하고,
`kubectl set image` 로 Deployment를 갱신한 뒤 파드가 Ready가 될 때까지 확인합니다.

### 6. 확인

```bash
kubectl get pods -n taskflow -o wide
terraform output application_url
```

파드 4개가 모두 `Running` 이고 출력된 주소로 접속되면 완료입니다.

---

## 삭제

Ingress를 먼저 지우고 ALB가 완전히 사라진 것을 확인한 뒤 destroy 하는 것을 권장합니다.

```bash
kubectl delete ingress taskflow-ingress -n taskflow
```

```bash
# ALB가 사라질 때까지 확인 (빈 결과가 나오면 완료)
aws elbv2 describe-load-balancers --region ap-northeast-2 \
  --query "LoadBalancers[?LoadBalancerName=='taskflow-alb'].State.Code" --output text
```

```bash
terraform destroy
```

ECR 레포지토리는 `force_delete = true` 라 이미지가 남아 있어도 삭제됩니다.

`destroy` 후 다시 세울 때는 **3번의 두 단계 apply부터 반복**하고,
ECR 이미지도 사라지므로 **5번의 워크플로우 실행도 다시** 해야 합니다.

### DependencyViolation 으로 실패했다면

ALB가 남아 서브넷과 인터넷 게이트웨이 삭제를 막는 상황입니다.
ALB는 Terraform이 아니라 AWS Load Balancer Controller가 만들기 때문에,
컨트롤러가 Ingress보다 먼저 제거되면 finalizer를 해제할 주체가 사라져 ALB가 남습니다.

```bash
# 1. Ingress finalizer 제거
kubectl patch ingress taskflow-ingress -n taskflow -p '{"metadata":{"finalizers":null}}' --type=merge

# 2. ALB 삭제
ALB_ARN=$(aws elbv2 describe-load-balancers --names taskflow-alb --region ap-northeast-2 \
  --query "LoadBalancers[0].LoadBalancerArn" --output text)
aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region ap-northeast-2

# 3. ALB가 사라진 뒤 대상 그룹 삭제
aws elbv2 describe-target-groups --region ap-northeast-2 \
  --query "TargetGroups[?starts_with(TargetGroupName,'k8s-taskflow')].TargetGroupArn" --output text \
  | xargs -n1 -I{} aws elbv2 delete-target-group --target-group-arn {} --region ap-northeast-2

# 4. 재실행
terraform destroy
```

VPC에 무엇이 남아 삭제를 막는지는 ENI 목록으로 확인할 수 있습니다.

```bash
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=<VPC_ID>" \
  --region ap-northeast-2 --query "NetworkInterfaces[].{Id:NetworkInterfaceId,Desc:Description}" --output table
```

---

## 버전

| 대상 | 버전 | 비고 |
|---|---|---|
| EKS | 1.36 | 지원 종료 버전은 노드 AMI가 제공되지 않아 노드 그룹 생성이 실패합니다 |
| 노드 AMI | AL2023 | 1.33부터 Amazon Linux 2 AMI는 지원되지 않습니다 |
| PostgreSQL | 17.10 | 사용 가능한 버전은 `aws rds describe-db-engine-versions` 로 확인 |
| aws-load-balancer-controller | 3.5.0 | |
| aws-for-fluent-bit | 0.2.0 | |
| kube-prometheus-stack | 88.1.3 | |
| metrics-server | 3.12.2 | |

---

## 자주 겪는 문제

| 증상 | 원인 및 대처 |
|---|---|
| `Provider configuration ... unknown value` | 첫 apply. 위 3번의 두 단계 방식으로 실행 |
| `Requested AMI for this version is not supported` | 지원 종료된 EKS 버전. `cluster_version` 을 올릴 것 |
| `Cannot find version X for postgres` | 해당 리전에 없는 엔진 버전. `describe-db-engine-versions` 로 확인 |
| `certificate ... is not yet valid` (webhook) | ALB Controller 웹훅 인증서의 유효 시작 시각이 미래. `time_sleep` 으로 대기하도록 되어 있으며, 그래도 나면 apply 재실행 |
| Helm 릴리스 타임아웃 | 노드가 아직 Ready가 아님. apply 재실행 |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | OIDC subject 불일치. CloudTrail의 `AssumeRoleWithWebIdentity` 이벤트에서 실제 subject를 확인할 것 |
| 파드가 계속 `ImagePullBackOff` | ECR에 이미지가 없음. 위 5번 실행 후 `kubectl rollout restart deployment -n taskflow` |

---

## 이름 변경

프로젝트 이름을 바꾸려면 `variable.tf` 의 기본값과 함께
아래 값들도 같이 바꿔야 합니다. 이름이 어긋나면 배포가 실패합니다.

- `variable.tf` — `project_name`, `cluster_name`, `k8s_namespace`, `ecr_repositories`, `db_secret_name`
- 각 앱 레포의 `.github/workflows/deploy.yaml` — `EKS_CLUSTER`, `K8S_NAMESPACE`, `ECR_REPOSITORY`, `DEPLOYMENT`
- `frontend/nginx.conf` — 프록시 대상 백엔드 서비스 이름

---

## 확인용 명령어

```bash
# 파드가 서로 다른 AZ의 노드에 분산되었는지
kubectl get pods -n taskflow -o wide

# 노드별 AZ
kubectl get nodes -L topology.kubernetes.io/zone

# 오토스케일링 상태
kubectl get hpa -n taskflow

# 파드를 강제 종료했을 때 복구 시간 측정
kubectl delete pod -n taskflow -l app=taskflow-backend --wait=false
kubectl get pods -n taskflow -w

# 알림 파이프라인 테스트 (경보를 강제로 ALARM 상태로 전환)
aws cloudwatch set-alarm-state \
  --alarm-name taskflow-error-logs \
  --state-value ALARM \
  --state-reason "알림 파이프라인 테스트" \
  --region ap-northeast-2

# Grafana 접속
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
terraform output -raw grafana_admin_password
```

---

## 비용

주요 과금 리소스는 EKS 컨트롤 플레인(시간당 약 $0.10), 워커 노드 t3.medium 2대,
NAT Gateway, RDS, ALB 입니다. 전체 합쳐 시간당 약 $0.35 수준이며,
확인이 끝나면 `terraform destroy` 로 정리하세요.
