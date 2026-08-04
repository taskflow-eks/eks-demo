variable "project_name" {
  description = "리소스 이름 접두사. Deployment / Service 이름의 앞부분이 됨"
  type        = string
}

variable "namespace" {
  description = "애플리케이션 네임스페이스"
  type        = string
}

variable "backend_service_account" {
  description = "백엔드 서비스 어카운트 이름"
  type        = string
}

variable "oidc_provider_arn" {
  description = "IRSA에 사용할 클러스터 OIDC 공급자 ARN"
  type        = string
}

variable "db_secret_arn" {
  description = "백엔드가 읽을 DB 자격증명 시크릿 ARN. IRSA 권한 범위를 이 시크릿으로 제한"
  type        = string
}

variable "db_secret_name" {
  description = "백엔드 컨테이너에 전달할 DB_SECRET_NAME 값"
  type        = string
}

variable "aws_region" {
  description = "백엔드가 Secrets Manager를 호출할 리전"
  type        = string
}

variable "ecr_registry" {
  description = "이미지 레지스트리 주소 (<account>.dkr.ecr.<region>.amazonaws.com)"
  type        = string
}

variable "frontend_image_tag" {
  description = "최초 생성 시 사용할 프론트엔드 이미지 태그. 이후 태그 변경은 배포 파이프라인이 담당"
  type        = string
  default     = "latest"
}

variable "backend_image_tag" {
  description = "최초 생성 시 사용할 백엔드 이미지 태그. 이후 태그 변경은 배포 파이프라인이 담당"
  type        = string
  default     = "latest"
}

variable "replicas" {
  description = "각 애플리케이션의 파드 수. AZ 분산을 위해 2 이상 권장"
  type        = number
  default     = 2
}

variable "backend_port" {
  description = "백엔드 컨테이너 포트"
  type        = number
  default     = 5000
}

variable "max_replicas" {
  description = "HPA가 확장할 수 있는 최대 파드 수"
  type        = number
  default     = 6
}

variable "hpa_cpu_target" {
  description = "HPA가 유지하려는 평균 CPU 사용률(%)"
  type        = number
  default     = 60
}

variable "pre_stop_sleep_seconds" {
  description = "종료 신호를 받은 뒤 ALB가 대상에서 제거할 때까지 기다리는 시간(초)"
  type        = number
  default     = 15
}

variable "termination_grace_seconds" {
  description = "파드 강제 종료까지의 유예 시간(초). preStop 대기 시간보다 커야 함"
  type        = number
  default     = 45
}

variable "deregistration_delay_seconds" {
  description = "ALB 대상 그룹 등록 해제 대기 시간(초). 기본값 300은 롤링 업데이트에 너무 김"
  type        = number
  default     = 30
}
