variable "repositories" {
  description = "생성할 ECR 레포지토리 이름 목록"
  type        = list(string)
}

variable "keep_image_count" {
  description = "레포지토리당 보관할 최근 이미지 개수"
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "이미지가 남아 있어도 레포지토리를 삭제할지 여부. 운영 환경에서는 false 권장"
  type        = bool
  default     = true
}
