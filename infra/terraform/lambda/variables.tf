variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "sns_topic_arn" {
  description = "구독할 SNS 토픽 ARN"
  type        = string
}

variable "discord_webhook_url" {
  description = "알림을 보낼 Discord 웹훅 URL"
  type        = string
  sensitive   = true
}

variable "log_retention_days" {
  description = "Lambda 로그 보관 기간(일)"
  type        = number
}

variable "runtime" {
  description = "Lambda 런타임"
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Lambda 실행 제한 시간(초)"
  type        = number
  default     = 15
}
