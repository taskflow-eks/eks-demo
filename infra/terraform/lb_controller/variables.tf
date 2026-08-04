variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "cluster_name" {
  description = "컨트롤러가 관리할 EKS 클러스터 이름"
  type        = string
}

variable "aws_region" {
  description = "ALB를 생성할 리전"
  type        = string
}

variable "vpc_id" {
  description = "ALB를 생성할 VPC"
  type        = string
}

variable "oidc_provider_arn" {
  description = "IRSA에 사용할 클러스터 OIDC 공급자 ARN"
  type        = string
}

variable "namespace" {
  description = "컨트롤러를 설치할 네임스페이스"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "컨트롤러 서비스 어카운트 이름"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "chart_version" {
  description = "aws-load-balancer-controller 차트 버전"
  type        = string
  default     = "3.5.0"
}
