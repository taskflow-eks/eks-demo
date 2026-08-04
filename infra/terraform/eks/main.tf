############################################################
# EKS 클러스터
#  - 워커 노드는 프라이빗 서브넷에 배치하고 두 AZ에 분산
#  - 컨트롤 플레인 엔드포인트는 퍼블릭으로 열어 GitHub Actions에서 kubectl 접근
############################################################

module "this" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  cluster_endpoint_public_access = true

  # terraform apply를 실행한 IAM 주체에게 클러스터 관리자 권한 부여
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {
    default = {
      name = "${var.project_name}-ng"

      # 1.33 이후로 Amazon Linux 2 AMI는 지원되지 않으므로 AL2023을 명시
      ami_type = "AL2023_x86_64_STANDARD"

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # 여러 AZ에 걸쳐 노드를 배치 → 파드가 서로 다른 AZ에 분산됨
      subnet_ids = var.subnet_ids
    }
  }

  cluster_enabled_log_types              = var.cluster_enabled_log_types
  cloudwatch_log_group_retention_in_days = var.log_retention_days
}
