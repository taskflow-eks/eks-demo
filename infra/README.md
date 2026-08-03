# TaskFlow Infrastructure

TaskFlow 서비스가 동작하는 AWS 인프라와 쿠버네티스 매니페스트를 관리합니다.

![Architecture](./taskflow-architecture.png)

## 구성

```
infra/
├── terraform/   AWS 인프라 (VPC, EKS, RDS, ECR, 모니터링, 알림)
└── k8s/         쿠버네티스 매니페스트 (Deployment, Service, Ingress)
```

## 설계 의도

**가용성** — 워커 노드를 서로 다른 두 가용영역에 배치하고, 프론트엔드와 백엔드를
각각 2개 replica로 분산했습니다. `topologySpreadConstraints`로 같은 AZ에 몰리지
않도록 해, 한쪽 AZ에 문제가 생겨도 남은 파드가 요청을 계속 처리합니다.

**격리** — 애플리케이션과 데이터베이스는 프라이빗 서브넷에만 배치했습니다.
외부에서 들어오는 트래픽은 ALB만 받고, 운영자 접근은 Bastion을 경유합니다.

**자격증명** — 파드에 액세스 키를 두지 않습니다. IRSA로 서비스 어카운트에
IAM 역할을 연결했고, GitHub Actions도 OIDC로 임시 자격증명을 발급받습니다.

**관측** — Fluent Bit이 컨테이너 로그를 CloudWatch로 모으고,
Prometheus·Grafana가 클러스터 지표를 수집합니다. 로그에서 에러가 감지되면
CloudWatch 경보 → SNS → Lambda → Discord 순으로 알림이 전달됩니다.

## 사용법

Terraform 실행 방법은 [terraform/README.md](./terraform/README.md)를 참고하세요.

매니페스트는 `main` 브랜치의 `k8s/` 가 변경되면 GitHub Actions가 자동으로 적용합니다.
Terraform 코드는 PR을 올리면 `fmt` · `validate` 검사가 실행됩니다.

## 관련 레포지토리

- 프론트엔드: `taskflow-frontend`
- 백엔드: `taskflow-backend`
