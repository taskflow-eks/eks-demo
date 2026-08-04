variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "vpc_id" {
  description = "RDS를 배치할 VPC"
  type        = string
}

variable "subnet_ids" {
  description = "RDS 서브넷 그룹에 사용할 프라이빗 서브넷"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "접속을 허용할 EKS 워커 노드 보안 그룹"
  type        = string
}

variable "bastion_security_group_id" {
  description = "접속을 허용할 Bastion 보안 그룹"
  type        = string
}

variable "db_name" {
  description = "생성할 데이터베이스 이름"
  type        = string
}

variable "db_username" {
  description = "마스터 사용자 이름"
  type        = string
}

variable "db_port" {
  description = "데이터베이스 포트"
  type        = number
  default     = 5432
}

variable "instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL 엔진 버전. 사용 가능한 값은 aws rds describe-db-engine-versions 로 확인"
  type        = string
}

variable "multi_az" {
  description = "다중 AZ 배포 여부 (비용이 약 2배)"
  type        = bool
  default     = false
}

variable "secret_name" {
  description = "자격증명을 저장할 Secrets Manager 시크릿 이름. backend Deployment의 DB_SECRET_NAME과 일치해야 함"
  type        = string
}

variable "allocated_storage" {
  description = "초기 스토리지 크기(GB)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "오토스케일링 상한(GB)"
  type        = number
  default     = 50
}

variable "backup_retention_period" {
  description = "자동 백업 보관 기간(일)"
  type        = number
  default     = 1
}
