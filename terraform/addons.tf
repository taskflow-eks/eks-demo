############################################
# 클러스터 애드온 (Helm)
#  - AWS Load Balancer Controller : Ingress → ALB 생성
#  - AWS for Fluent Bit           : 컨테이너 로그 → CloudWatch 중앙화
#  - kube-prometheus-stack        : Prometheus + Grafana
############################################

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  values = [yamlencode({
    clusterName = module.eks.cluster_name
    region      = var.aws_region
    vpcId       = module.vpc.vpc_id

    serviceAccount = {
      create = false
      name   = kubernetes_service_account_v1.alb_controller.metadata[0].name
    }
  })]

  depends_on = [
    module.eks,
    kubernetes_service_account_v1.alb_controller,
  ]
}

# 애플리케이션 컨테이너 로그가 모이는 로그 그룹
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days
}

resource "helm_release" "fluent_bit" {
  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  namespace  = "kube-system"
  version    = "0.1.34"

  values = [yamlencode({
    serviceAccount = {
      create = false
      name   = kubernetes_service_account_v1.fluent_bit.metadata[0].name
    }

    cloudWatchLogs = {
      enabled         = true
      region          = var.aws_region
      logGroupName    = aws_cloudwatch_log_group.application.name
      logStreamPrefix = "fluentbit-"
      autoCreateGroup = false
    }

    # 기본으로 켜져 있는 다른 출력은 사용하지 않음
    firehose      = { enabled = false }
    kinesis       = { enabled = false }
    elasticsearch = { enabled = false }
  })]

  depends_on = [
    module.eks,
    kubernetes_service_account_v1.fluent_bit,
    aws_cloudwatch_log_group.application,
  ]
}

# --- Prometheus / Grafana ---------------------------------------------------

resource "random_password" "grafana" {
  count = var.enable_monitoring_stack ? 1 : 0

  length  = 20
  special = false
}

resource "helm_release" "kube_prometheus_stack" {
  count = var.enable_monitoring_stack ? 1 : 0

  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "62.3.0"

  # 노드가 2대뿐이라 리소스를 넉넉하게 잡지 않음
  values = [yamlencode({
    grafana = {
      adminPassword = random_password.grafana[0].result
      service       = { type = "ClusterIP" }
    }

    prometheus = {
      prometheusSpec = {
        retention = "6h"
        resources = {
          requests = { cpu = "200m", memory = "512Mi" }
          limits   = { cpu = "500m", memory = "1Gi" }
        }
      }
    }

    alertmanager = { enabled = false }
  })]

  depends_on = [module.eks]
}
