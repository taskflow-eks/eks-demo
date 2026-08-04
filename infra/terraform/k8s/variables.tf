variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "namespace" {
  description = "애플리케이션 네임스페이스. k8s/namespace.yaml과 일치해야 함"
  type        = string
}

variable "backend_service_account" {
  description = "백엔드 서비스 어카운트 이름. backend-deployment.yaml과 일치해야 함"
  type        = string
}

variable "oidc_provider_arn" {
  description = "IRSA에 사용할 클러스터 OIDC 공급자 ARN"
  type        = string
}

variable "db_secret_arn" {
  description = "백엔드가 읽을 DB 자격증명 시크릿 ARN"
  type        = string
}
