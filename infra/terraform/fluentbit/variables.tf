variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "cluster_name" {
  description = "로그 그룹 이름에 사용할 클러스터 이름"
  type        = string
}

variable "aws_region" {
  description = "로그를 전송할 리전"
  type        = string
}

variable "oidc_provider_arn" {
  description = "IRSA에 사용할 클러스터 OIDC 공급자 ARN"
  type        = string
}

variable "log_retention_days" {
  description = "애플리케이션 로그 보관 기간(일)"
  type        = number
}

variable "namespace" {
  description = "Fluent Bit을 설치할 네임스페이스"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Fluent Bit 서비스 어카운트 이름"
  type        = string
  default     = "aws-for-fluent-bit"
}

variable "chart_version" {
  description = "aws-for-fluent-bit 차트 버전"
  type        = string
  default     = "0.2.0"
}
