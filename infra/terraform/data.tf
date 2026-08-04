data "aws_caller_identity" "current" {}

# kubernetes / helm 프로바이더 인증에 사용
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}
