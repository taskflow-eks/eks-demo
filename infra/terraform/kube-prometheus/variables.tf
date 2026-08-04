variable "namespace" {
  description = "모니터링 스택을 설치할 네임스페이스"
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "kube-prometheus-stack 차트 버전"
  type        = string
  default     = "88.1.3"
}

variable "prometheus_retention" {
  description = "지표 보관 기간. 노드가 2대뿐이라 짧게 유지"
  type        = string
  default     = "6h"
}
