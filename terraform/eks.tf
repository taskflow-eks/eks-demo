############################################
# EKS 클러스터
#  - 워커 노드는 프라이빗 서브넷에 배치하고 두 AZ에 분산
#  - 컨트롤 플레인 엔드포인트는 퍼블릭으로 열어 GitHub Actions에서 kubectl 접근
############################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

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

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # 여러 AZ에 걸쳐 노드를 배치 → 파드가 서로 다른 AZ에 분산됨
      subnet_ids = module.vpc.private_subnets
    }
  }

  # 클러스터 컨트롤 플레인 로그 (CloudWatch)
  cluster_enabled_log_types              = ["api", "audit", "authenticator"]
  cloudwatch_log_group_retention_in_days = var.log_retention_days
}

# 애플리케이션 네임스페이스
# (k8s/namespace.yaml과 중복이지만, IRSA 서비스 어카운트를 만들려면 먼저 존재해야 함)
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.k8s_namespace
  }

  depends_on = [module.eks]
}

# 백엔드용 서비스 어카운트
# app.py가 Secrets Manager에서 DB 자격증명을 읽으므로 IRSA로 권한을 부여
resource "kubernetes_service_account_v1" "backend" {
  metadata {
    name      = var.backend_service_account
    namespace = kubernetes_namespace_v1.app.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = module.backend_irsa.iam_role_arn
    }
  }
}
