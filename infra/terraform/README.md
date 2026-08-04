# TaskFlow Infrastructure (Terraform)

EKS 기반 컨테이너 서비스 인프라를 코드로 관리합니다.
네트워크부터 클러스터, 애플리케이션 워크로드, 관측·알림까지 `terraform apply` 로 재현됩니다.

---

## 구성

루트에서는 모듈을 조립만 하고, 실제 리소스는 각 모듈이 정의합니다.

```
terraform/
├── main.tf         모듈 호출 및 의존 관계
├── provider.tf     프로바이더 설정
├── variable.tf     입력 변수
├── outputs.tf      출력값
├── data.tf         계정 정보, 클러스터 인증
└── <모듈>/          main.tf · variables.tf · outputs.tf
```

| 모듈 | 내용 |
|---|---|
| `vpc` | VPC, 퍼블릭/프라이빗 서브넷(2 AZ), IGW, NAT Gateway |
| `eks` | EKS 클러스터, 관리형 노드 그룹, 컨트롤 플레인 로그 |
| `ecr` | 프론트/백엔드 이미지 레포지토리 + 라이프사이클 정책 |
| `rds` | PostgreSQL, 보안 그룹, Secrets Manager 자격증명 |
| `bastion` | 퍼블릭 서브넷 Bastion (SSM 접속) |
| `k8s` | 네임스페이스, 백엔드 IRSA, Deployment · Service · Ingress · HPA |
| `lb_controller` | AWS Load Balancer Controller (IRSA + Helm) |
| `metrics_server` | HPA가 CPU를 읽기 위한 metrics.k8s.io API |
| `fluentbit` | 컨테이너 로그 → CloudWatch 중앙화 (IRSA + Helm + 로그 그룹) |
| `kube-prometheus` | Prometheus + Grafana |
| `monitoring` | 로그 지표 필터, CloudWatch 경보, SNS 토픽 |
| `lambda` | SNS → Discord 알림 전달 함수 |
| `github_oidc` | GitHub Actions OIDC 역할 및 EKS 접근 권한 |

각 모듈이 필요한 값만 변수로 받고 다른 모듈이 쓸 값만 출력하므로,
모듈 사이에 무엇이 오가는지가 인터페이스로 드러납니다.
예를 들어 `rds` 는 접속을 허용할 보안 그룹 ID를 입력으로 받고,
`k8s` 는 권한 범위를 좁히기 위해 시크릿 ARN을 입력으로 받습니다.

`enable_monitoring_stack`, `discord_webhook_url`, `github_repositories` 값에 따라
해당 모듈을 통째로 생성하지 않을 수 있어, 코드를 고치지 않고
`terraform.tfvars` 만으로 범위를 조절할 수 있습니다.

---

## 사전 준비

| 도구 | 확인 |
|---|---|
| Terraform >= 1.5 | `terraform -version` |
| AWS CLI v2 (자격증명 설정 완료) | `aws sts get-caller-identity` |
| kubectl | `kubectl version --client` |

GitHub 레포지토리 세 곳(`taskflow-frontend`, `taskflow-backend`, `taskflow-infra`)에
Actions Secret 을 등록합니다.

```
AWS_ACCOUNT_ID = <12자리 AWS 계정 ID>
```

---

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

```bash
terraform destroy
```

ALB는 Ingress가 만들지만 그 Ingress를 Terraform이 관리하므로,
파괴 순서상 Ingress가 먼저 제거되어 ALB도 함께 정리됩니다.
ECR 레포지토리는 `force_delete = true` 라 이미지가 남아 있어도 삭제됩니다.

`destroy` 후 다시 세울 때는 **3번의 두 단계 apply부터 반복**하고,
ECR 이미지도 사라지므로 **5번의 워크플로우 실행도 다시** 해야 합니다.

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
