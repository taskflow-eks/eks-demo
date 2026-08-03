variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project_name" {
  type    = string
  default = "taskflow"
}

# --- 네트워크 -------------------------------------------------------------

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/20", "10.0.16.0/20"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.32.0/20", "10.0.48.0/20"]
}

# --- EKS ------------------------------------------------------------------

variable "cluster_name" {
  type    = string
  default = "taskflow-cluster"
}

variable "cluster_version" {
  type    = string
  default = "1.30"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "k8s_namespace" {
  type    = string
  default = "taskflow"
}

variable "backend_service_account" {
  type    = string
  default = "backend-sa"
}

# --- ECR ------------------------------------------------------------------

variable "ecr_repositories" {
  type    = list(string)
  default = ["taskflow-frontend", "taskflow-backend"]
}

# --- RDS ------------------------------------------------------------------

variable "db_name" {
  type    = string
  default = "taskflowdb"
}

variable "db_username" {
  type    = string
  default = "postgres"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_engine_version" {
  type    = string
  default = "16.3"
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_secret_name" {
  type    = string
  default = "taskflow-db"
}

# --- Bastion --------------------------------------------------------------

variable "bastion_key_name" {
  type    = string
  default = ""
}

variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

# --- 모니터링 / 알림 -------------------------------------------------------

variable "discord_webhook_url" {
  type      = string
  default   = ""
  sensitive = true
}

variable "enable_monitoring_stack" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 7
}

# --- GitHub Actions OIDC --------------------------------------------------

variable "github_repository" {
  type    = string
  default = ""
}
