locals {
  notification_enabled = var.discord_webhook_url != ""
  oidc_enabled         = length(var.github_repositories) > 0
}

############################################################
# 네트워크
############################################################

module "vpc" {
  source = "./vpc"

  project_name         = var.project_name
  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

############################################################
# 컨테이너 플랫폼
############################################################

module "eks" {
  source = "./eks"

  project_name    = var.project_name
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size

  log_retention_days = var.log_retention_days
}

module "ecr" {
  source = "./ecr"

  repositories = var.ecr_repositories
}

############################################################
# 데이터베이스 · 접근 경로
############################################################

module "rds" {
  source = "./rds"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets

  node_security_group_id    = module.eks.node_security_group_id
  bastion_security_group_id = module.bastion.security_group_id

  db_name        = var.db_name
  db_username    = var.db_username
  instance_class = var.db_instance_class
  engine_version = var.db_engine_version
  multi_az       = var.db_multi_az
  secret_name    = var.db_secret_name
}

module "bastion" {
  source = "./bastion"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.public_subnets[0]
  allowed_ssh_cidr = var.allowed_ssh_cidr
  key_name         = var.bastion_key_name
}

############################################################
# 애플리케이션 네임스페이스 · IRSA
############################################################

module "k8s" {
  source = "./k8s"

  project_name            = var.project_name
  namespace               = var.k8s_namespace
  backend_service_account = var.backend_service_account

  oidc_provider_arn = module.eks.oidc_provider_arn
  db_secret_arn     = module.rds.secret_arn
}

############################################################
# 클러스터 애드온
############################################################

module "lb_controller" {
  source = "./lb_controller"

  project_name      = var.project_name
  cluster_name      = module.eks.cluster_name
  aws_region        = var.aws_region
  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
}

module "fluentbit" {
  source = "./fluentbit"

  project_name       = var.project_name
  cluster_name       = module.eks.cluster_name
  aws_region         = var.aws_region
  oidc_provider_arn  = module.eks.oidc_provider_arn
  log_retention_days = var.log_retention_days
}

# ALB Controller가 설치되면 Service 생성 요청이 웹훅을 거치게 된다.
# 이때 웹훅 인증서의 유효 시작 시각이 수십 초 뒤로 잡혀 있어,
# 바로 Service를 만들면 "certificate ... is not yet valid" 로 거부된다.
# 인증서가 유효해질 때까지 기다린 뒤 이후 릴리스를 설치한다.
resource "time_sleep" "wait_for_alb_webhook" {
  depends_on = [module.lb_controller]

  create_duration = "90s"
}

module "kube_prometheus" {
  source = "./kube-prometheus"
  count  = var.enable_monitoring_stack ? 1 : 0

  depends_on = [
    module.eks,
    time_sleep.wait_for_alb_webhook,
  ]
}

############################################################
# 장애 감지 → 알림
#  discord_webhook_url 이 비어 있으면 감지·알림 리소스를 만들지 않음
############################################################

module "monitoring" {
  source = "./monitoring"
  count  = local.notification_enabled ? 1 : 0

  project_name   = var.project_name
  log_group_name = module.fluentbit.log_group_name
  db_identifier  = module.rds.db_identifier
}

module "lambda" {
  source = "./lambda"
  count  = local.notification_enabled ? 1 : 0

  project_name        = var.project_name
  sns_topic_arn       = module.monitoring[0].sns_topic_arn
  discord_webhook_url = var.discord_webhook_url
  log_retention_days  = var.log_retention_days
}

############################################################
# CI/CD 자격증명
############################################################

module "github_oidc" {
  source = "./github_oidc"
  count  = local.oidc_enabled ? 1 : 0

  project_name = var.project_name
  repositories = var.github_repositories

  ecr_repository_arns = module.ecr.repository_arns
  cluster_name        = module.eks.cluster_name
  cluster_arn         = module.eks.cluster_arn
}
