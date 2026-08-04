variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "vpc_id" {
  description = "Bastion을 배치할 VPC"
  type        = string
}

variable "subnet_id" {
  description = "Bastion을 배치할 퍼블릭 서브넷"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "SSH 접속을 허용할 CIDR"
  type        = string

  validation {
    condition     = var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "SSH를 전체 개방할 수 없습니다. 접속할 IP를 /32로 지정하세요."
  }
}

variable "key_name" {
  description = "연결할 EC2 키페어 이름. 비우면 SSM Session Manager로만 접속"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Bastion 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "kubectl_version" {
  description = "Bastion에 설치할 kubectl 버전"
  type        = string
  default     = "v1.36.0"
}
