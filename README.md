# TaskFlow

EKS 위에서 동작하는 할 일 관리 서비스입니다. 애플리케이션보다는
**배포 자동화 · 관측 · 고가용성을 갖춘 인프라를 직접 설계하고 구축하는 것**이 목적입니다.

![Architecture](./infra/taskflow-architecture.png)

## 구조

이 저장소는 세 개의 저장소로 나누어 배포됩니다.

| 디렉터리 | 배포 대상 저장소 | 내용 |
|---|---|---|
| `frontend/` | `taskflow-frontend` | React + Vite + Nginx |
| `backend/` | `taskflow-backend` | Flask API |
| `infra/` | `taskflow-infra` | Terraform, 쿠버네티스 매니페스트 |

각 디렉터리 안의 `.github/workflows/` 는 해당 저장소로 올라갔을 때
저장소 루트가 되어 동작합니다.

## 하위 디렉터리를 각 저장소로 푸시

원격을 한 번만 등록해 두면 됩니다.

```bash
git remote add frontend https://github.com/<org>/taskflow-frontend.git
git remote add backend  https://github.com/<org>/taskflow-backend.git
git remote add infra    https://github.com/<org>/taskflow-infra.git
```

이후 변경된 부분만 푸시합니다.

```bash
git subtree push --prefix=frontend frontend main
git subtree push --prefix=backend  backend  main
git subtree push --prefix=infra    infra    main
```

## 기술 스택

**AWS** — EKS, VPC, ECR, RDS(PostgreSQL), ALB, NAT Gateway, Secrets Manager,
CloudWatch, SNS, Lambda, IAM(IRSA / OIDC)

**Others** — Terraform, GitHub Actions, Fluent Bit, Prometheus, Grafana, Discord Webhook
