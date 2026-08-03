############################################
# VPC
#  - 퍼블릭 서브넷: ALB, NAT Gateway, Bastion
#  - 프라이빗 서브넷: EKS 워커 노드, RDS
#  - 두 개의 가용영역에 나누어 배치해 한쪽 AZ 장애에도 서비스가 유지되도록 구성
############################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # 프라이빗 서브넷의 아웃바운드 통신용 (ECR 이미지 pull, CloudWatch 전송 등)
  # single_nat_gateway = true 는 비용 절감용. 운영 환경이라면 AZ별로 두는 것을 권장
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # AWS Load Balancer Controller가 서브넷을 자동으로 찾기 위한 태그
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
