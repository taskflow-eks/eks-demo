variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "cluster_version" {
  description = "쿠버네티스 버전. 지원 종료된 버전은 노드 AMI가 제공되지 않아 노드 그룹 생성이 실패함"
  type        = string
}

variable "vpc_id" {
  description = "클러스터를 배치할 VPC"
  type        = string
}

variable "subnet_ids" {
  description = "워커 노드를 배치할 서브넷 (프라이빗, 2개 AZ 이상)"
  type        = list(string)
}

variable "node_instance_types" {
  description = "워커 노드 인스턴스 타입"
  type        = list(string)
}

variable "node_min_size" {
  description = "워커 노드 최소 개수"
  type        = number
}

variable "node_max_size" {
  description = "워커 노드 최대 개수"
  type        = number
}

variable "node_desired_size" {
  description = "워커 노드 기본 개수"
  type        = number
}

variable "cluster_enabled_log_types" {
  description = "CloudWatch로 내보낼 컨트롤 플레인 로그 종류"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "log_retention_days" {
  description = "컨트롤 플레인 로그 보관 기간(일)"
  type        = number
}
