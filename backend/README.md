# TaskFlow Backend

Flask로 작성한 할 일 관리 API입니다. RDS PostgreSQL을 사용하며, DB 접속 정보는
코드나 환경변수에 두지 않고 AWS Secrets Manager에서 읽어옵니다.

## API

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/` | 응답한 파드 이름과 버전 반환 |
| GET | `/health` | 헬스체크 (liveness / readiness probe에서 사용) |
| GET | `/tasks` | 할 일 목록 조회 |
| POST | `/tasks` | 할 일 생성 |
| PUT | `/tasks/<id>` | 할 일 수정 |
| DELETE | `/tasks/<id>` | 할 일 삭제 |

`GET /` 가 파드 이름을 반환하기 때문에, 프론트엔드 화면을 새로고침하면
어느 파드가 응답했는지 눈으로 확인할 수 있습니다. ALB가 여러 파드로
트래픽을 분산하고 있는지 확인하는 용도로 사용합니다.

## 자격증명

`DB_SECRET_NAME` 환경변수에 지정된 Secrets Manager 시크릿에서
`host`, `port`, `dbname`, `username`, `password` 를 읽습니다.

파드에는 액세스 키를 넣지 않고, IRSA로 서비스 어카운트(`backend-sa`)에
IAM 역할을 연결해 해당 시크릿만 읽을 수 있도록 권한을 제한했습니다.

`DB_SECRET_NAME`이 없으면 로컬 개발용 환경변수로 대체됩니다.

## 로컬 실행

```bash
pip install -r requirements.txt
python app.py
```

## 배포

`main` 브랜치에 푸시하면 GitHub Actions가 문법 검사 후 이미지를 빌드해
ECR에 푸시하고, Deployment 이미지를 교체한 뒤 파드가 Ready가 될 때까지 확인합니다.

## 관련 레포지토리

- 프론트엔드: `taskflow-frontend`
- 인프라(Terraform, 쿠버네티스 매니페스트): `taskflow-infra`
