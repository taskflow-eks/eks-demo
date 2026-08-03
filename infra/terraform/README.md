# TaskFlow Infrastructure (Terraform)

EKS 기반 컨테이너 서비스 인프라를 코드로 관리합니다.

## 구성

| 파일 | 내용 |
|---|---|
| `vpc.tf` | VPC, 퍼블릭/프라이빗 서브넷(2 AZ), IGW, NAT Gateway |
| `eks.tf` | EKS 클러스터, 관리형 노드 그룹, 네임스페이스, 백엔드 서비스 어카운트 |
| `ecr.tf` | 프론트/백엔드 이미지 레포지토리 + 라이프사이클 정책 |
| `rds.tf` | PostgreSQL, 보안 그룹, Secrets Manager 자격증명 |
| `bastion.tf` | 퍼블릭 서브넷 Bastion (SSM 접속 가능) |
| `irsa.tf` | 백엔드 / ALB Controller / Fluent Bit 용 IRSA 역할 |
| `addons.tf` | AWS Load Balancer Controller, Fluent Bit, kube-prometheus-stack |
| `monitoring.tf` | 로그 지표 필터 → CloudWatch 경보 → SNS → Lambda → Discord |
| `github-oidc.tf` | GitHub Actions OIDC 역할 및 EKS 접근 권한 |

## 사용법

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # 값 채우기
terraform init
terraform plan
terraform apply
```

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

## 적용 순서 주의

`aws_vpc_security_group_ingress_rule.rds_from_nodes` 가 EKS 노드 보안 그룹을 참조하므로
`terraform apply` 는 한 번에 실행하면 되지만, Helm 릴리스는 노드가 Ready 된 뒤에 설치됩니다.
첫 apply에서 Helm 단계가 타임아웃되면 `terraform apply` 를 다시 실행하면 됩니다.

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
