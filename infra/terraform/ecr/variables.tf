variable "repositories" {
  description = "생성할 ECR 레포지토리 이름 목록"
  type        = list(string)
}

variable "keep_image_count" {
  description = "레포지토리당 보관할 최근 이미지 개수"
  type        = number
  default     = 10
}
