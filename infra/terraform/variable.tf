variable "aws_region" {
  description = "리소스를 생성할 AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "리소스 이름 접두사 및 공통 태그에 사용할 프로젝트 이름"
  type        = string
  default     = "taskflow"
}

# --- 네트워크 ---------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "사용할 가용영역. 다중 AZ 이중화를 위해 2개 이상"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]

  validation {
    condition     = length(var.azs) >= 2
    error_message = "AZ 장애에 대비하려면 가용영역을 2개 이상 지정해야 합니다."
  }
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록. azs와 순서를 맞출 것"
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20"]
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 목록. azs와 순서를 맞출 것"
  type        = list(string)
  default     = ["10.0.32.0/20", "10.0.48.0/20"]
}

# --- EKS --------------------------------------------------------------------

variable "cluster_name" {
  description = "EKS 클러스터 이름. 각 레포 워크플로우의 EKS_CLUSTER와 일치해야 함"
  type        = string
  default     = "taskflow-cluster"
}

variable "cluster_version" {
  description = "쿠버네티스 버전. 지원 종료된 버전은 노드 AMI가 제공되지 않아 노드 그룹 생성이 실패함"
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  description = "워커 노드 인스턴스 타입"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "워커 노드 기본 개수. AZ 수와 맞추면 AZ당 1대가 배치됨"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "워커 노드 최소 개수"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "워커 노드 최대 개수"
  type        = number
  default     = 4
}

variable "k8s_namespace" {
  description = "애플리케이션 네임스페이스. k8s/namespace.yaml과 일치해야 함"
  type        = string
  default     = "taskflow"
}

variable "backend_service_account" {
  description = "백엔드 서비스 어카운트 이름"
  type        = string
  default     = "backend-sa"
}

variable "app_replicas" {
  description = "프론트엔드 / 백엔드 각각의 파드 수. AZ 분산을 위해 2 이상"
  type        = number
  default     = 2

  validation {
    condition     = var.app_replicas >= 2
    error_message = "한쪽 AZ 장애에도 서비스가 유지되려면 replica가 2개 이상이어야 합니다."
  }
}

variable "app_max_replicas" {
  description = "HPA가 확장할 수 있는 최대 파드 수"
  type        = number
  default     = 6
}

variable "hpa_cpu_target" {
  description = "HPA가 유지하려는 평균 CPU 사용률(%)"
  type        = number
  default     = 60
}

# --- ECR --------------------------------------------------------------------

variable "ecr_repositories" {
  description = "생성할 ECR 레포지토리 목록. k8s 매니페스트의 image 경로와 일치해야 함"
  type        = list(string)
  default     = ["taskflow-frontend", "taskflow-backend"]
}

# --- RDS --------------------------------------------------------------------

variable "db_name" {
  description = "생성할 데이터베이스 이름"
  type        = string
  default     = "taskflowdb"
}

variable "db_username" {
  description = "데이터베이스 마스터 사용자 이름"
  type        = string
  default     = "postgres"
}

variable "db_instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL 엔진 버전. aws rds describe-db-engine-versions 로 사용 가능한 값 확인"
  type        = string
  default     = "17.10"
}

variable "db_multi_az" {
  description = "RDS 다중 AZ 배포 여부. 비용이 약 2배가 되므로 기본은 비활성"
  type        = bool
  default     = false
}

variable "db_secret_name" {
  description = "DB 자격증명을 저장할 시크릿 이름. backend Deployment의 DB_SECRET_NAME과 일치해야 함"
  type        = string
  default     = "taskflow-db"
}

# --- Bastion ----------------------------------------------------------------

variable "bastion_key_name" {
  description = "Bastion에 연결할 기존 EC2 키페어 이름. 비우면 SSM Session Manager로만 접속"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "Bastion SSH 접속을 허용할 CIDR. 반드시 접속할 IP를 /32로 지정"
  type        = string
}

# --- 모니터링 · 알림 ---------------------------------------------------------

variable "enable_monitoring_stack" {
  description = "Prometheus / Grafana 설치 여부"
  type        = bool
  default     = true
}

variable "discord_webhook_url" {
  description = "장애 알림을 보낼 Discord 웹훅 URL. 비우면 감지·알림 리소스를 만들지 않음"
  type        = string
  default     = ""
  sensitive   = true
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보관 기간(일)"
  type        = number
  default     = 7
}

# --- GitHub Actions OIDC ----------------------------------------------------

variable "github_repositories" {
  description = "OIDC로 AWS 접근을 허용할 레포지토리 목록(owner/repo). 비우면 역할을 만들지 않음"
  type        = list(string)
  default     = []
}
