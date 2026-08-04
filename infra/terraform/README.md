# TaskFlow Infrastructure (Terraform)

EKS 기반 컨테이너 서비스 인프라를 코드로 관리합니다.

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
| `k8s` | 애플리케이션 네임스페이스, 백엔드 서비스 어카운트 및 IRSA |
| `lb_controller` | AWS Load Balancer Controller (IRSA + Helm) |
| `fluentbit` | 컨테이너 로그 → CloudWatch 중앙화 (IRSA + Helm + 로그 그룹) |
| `kube-prometheus` | Prometheus + Grafana |
| `monitoring` | 로그 지표 필터, CloudWatch 경보, SNS 토픽 |
| `lambda` | SNS → Discord 알림 전달 함수 |
| `github_oidc` | GitHub Actions OIDC 역할 및 EKS 접근 권한 |

### 모듈로 나눈 이유

각 모듈이 필요한 값만 변수로 받고 다른 모듈이 쓸 값만 출력하므로,
모듈 사이에 무엇이 오가는지가 인터페이스로 드러납니다.
예를 들어 `rds` 는 접속을 허용할 보안 그룹 ID를 입력으로 받고,
`k8s` 는 권한 범위를 좁히기 위해 시크릿 ARN을 입력으로 받습니다.

`enable_monitoring_stack`, `discord_webhook_url`, `github_repositories` 값에 따라
해당 모듈을 통째로 생성하지 않을 수 있어, 코드를 주석 처리하지 않고
`terraform.tfvars` 만으로 범위를 조절할 수 있습니다.

## 사용법

`terraform.tfvars.example` 을 `terraform.tfvars` 로 복사해 값을 채운 뒤 실행합니다.

```bash
terraform init
terraform plan
```

apply는 **두 단계로 나누어 실행합니다.**

```bash
# 1단계: 네트워크와 클러스터
terraform apply -target=module.vpc -target=module.eks

# 2단계: 나머지 전부
terraform apply
```

### 왜 나누어 실행하는가

`kubernetes` · `helm` 프로바이더는 클러스터 엔드포인트와 인증서를 받아 설정되는데,
이 값들은 같은 apply 안에서 생성되는 `module.eks` 의 출력입니다.
클러스터가 아직 없는 첫 실행에서는 프로바이더 설정값이 확정되지 않아
Terraform이 `Provider configuration ... unknown value` 로 실패합니다.

클러스터를 먼저 만들어 두면 두 번째 apply에서는 값이 확정되어 있으므로 정상 동작합니다.
클러스터가 이미 존재하는 이후 실행부터는 `terraform apply` 한 번으로 충분합니다.

> 근본적으로는 클러스터와 애드온을 별도 루트 모듈로 분리하는 것이 맞습니다.
> 이 레포는 규모가 작아 단일 루트 모듈로 두고 실행 순서로 해결했습니다.

생성 후 kubeconfig 설정:

```bash
aws eks update-kubeconfig --region ap-northeast-2 --name taskflow-cluster
```

전부 삭제:

```bash
terraform destroy
```

> ALB는 Ingress가 만들기 때문에 Terraform이 모르는 리소스입니다.
> `terraform destroy` 전에 `kubectl delete -f ../k8s/ingress.yaml` 을 먼저 실행하세요.
> 그렇지 않으면 ALB와 보안 그룹이 남아 VPC 삭제가 실패합니다.

## 버전

| 대상 | 버전 | 비고 |
|---|---|---|
| EKS | 1.36 | 지원 종료 버전은 노드 AMI가 제공되지 않아 노드 그룹 생성이 실패합니다 |
| 노드 AMI | AL2023 | 1.33부터 Amazon Linux 2 AMI는 지원되지 않습니다 |
| PostgreSQL | 17.10 | 사용 가능한 버전은 `aws rds describe-db-engine-versions` 로 확인 |
| aws-load-balancer-controller | 3.5.0 | |
| aws-for-fluent-bit | 0.2.0 | |
| kube-prometheus-stack | 88.1.3 | |

## 자주 겪는 문제

| 증상 | 원인 및 대처 |
|---|---|
| `Requested AMI for this version is not supported` | 지원 종료된 EKS 버전. `cluster_version` 을 올릴 것 |
| `Cannot find version X for postgres` | 해당 리전에 없는 엔진 버전. `describe-db-engine-versions` 로 확인 |
| Helm 릴리스 타임아웃 | 노드가 아직 Ready가 아님. `terraform apply` 재실행 |
| `Provider configuration ... unknown value` | 위 2단계 apply로 해결 |

## 이름 변경

프로젝트 이름을 바꾸려면 `variables.tf` 의 기본값과 함께
아래 파일들의 값도 같이 바꿔야 합니다. (이름이 어긋나면 배포가 실패합니다)

- `k8s/*.yaml` — 네임스페이스, Deployment/Service 이름, 이미지 경로, `DB_SECRET_NAME`
- `.github/workflows/deploy.yaml` — `EKS_CLUSTER`, `K8S_NAMESPACE`, 이미지 태그, rollout 대상
- `frontend/nginx.conf` — 백엔드 서비스 이름

## 확인용 명령어

```bash
# 파드가 서로 다른 AZ의 노드에 분산되었는지
kubectl get pods -n taskflow -o wide

# 노드별 AZ
kubectl get nodes -L topology.kubernetes.io/zone

# 파드를 강제 종료했을 때 복구 시간 측정
kubectl delete pod -n taskflow -l app=taskflow-backend --wait=false
kubectl get pods -n taskflow -w

# Grafana 접속 (비밀번호는 terraform output)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
terraform output -raw grafana_admin_password
```

## 비용

주요 과금 리소스는 EKS 컨트롤 플레인(시간당 약 $0.10), 워커 노드 t3.medium 2대,
NAT Gateway, RDS, ALB 입니다. 확인이 끝나면 `terraform destroy` 로 정리하세요.
