variable "project_name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "repositories" {
  description = "역할을 맡을 수 있는 GitHub 레포지토리 목록 (owner/repo)"
  type        = list(string)

  validation {
    condition     = length(var.repositories) > 0
    error_message = "허용할 레포지토리를 최소 하나 지정해야 합니다."
  }
}

variable "allowed_branch" {
  description = "역할을 맡을 수 있는 브랜치"
  type        = string
  default     = "main"
}

variable "ecr_repository_arns" {
  description = "이미지 push를 허용할 ECR 레포지토리 ARN 목록"
  type        = list(string)
}

variable "cluster_name" {
  description = "접근 권한을 등록할 EKS 클러스터 이름"
  type        = string
}

variable "cluster_arn" {
  description = "eks:DescribeCluster를 허용할 클러스터 ARN"
  type        = string
}

variable "eks_access_policy_arn" {
  description = "역할에 연결할 EKS 접근 정책. 운영 환경이라면 네임스페이스 범위로 좁힐 것"
  type        = string
  default     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}
