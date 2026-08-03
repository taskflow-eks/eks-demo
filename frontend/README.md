# TaskFlow Frontend

React + Vite로 작성한 프론트엔드입니다. 빌드 결과물은 Nginx 이미지로 패키징되어 EKS에 배포됩니다.

## 구성

- React 18, Vite 5
- Nginx (정적 파일 서빙 + `/api` 요청을 백엔드 서비스로 프록시)
- 멀티스테이지 Dockerfile (빌드 스테이지 / 실행 스테이지 분리)

## 로컬 실행

```bash
npm install
npm run dev
```

`/api` 요청은 `vite.config.js`의 프록시 설정에 따라 `http://localhost:5000`으로 전달됩니다.
백엔드를 먼저 띄워야 할 일 목록이 보입니다.

## 배포

`main` 브랜치에 푸시하면 GitHub Actions가 실행됩니다.

1. `npm run build` 로 빌드가 깨지지 않는지 검증
2. 이미지 빌드 후 ECR에 푸시 (태그: 커밋 SHA)
3. `kubectl set image` 로 Deployment 이미지 교체
4. `kubectl rollout status` 로 파드가 Ready가 될 때까지 확인

3번까지만 하면 파드가 뜨지 않아도 워크플로우가 성공으로 끝나기 때문에,
4번에서 실제 기동을 확인한 뒤에 배포를 완료로 처리합니다.

## 관련 레포지토리

- 백엔드: `taskflow-backend`
- 인프라(Terraform, 쿠버네티스 매니페스트): `taskflow-infra`
