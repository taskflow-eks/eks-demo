variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "log_group_name" {
  description = "지표 필터를 걸 애플리케이션 로그 그룹"
  type        = string
}

variable "db_identifier" {
  description = "CPU 경보를 걸 RDS 인스턴스 식별자"
  type        = string
}

variable "error_pattern" {
  description = "에러로 판단할 로그 필터 패턴"
  type        = string
  default     = "ERROR"
}

variable "rds_cpu_threshold" {
  description = "RDS CPU 경보 임계치(%)"
  type        = number
  default     = 80
}
