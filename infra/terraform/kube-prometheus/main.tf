############################################################
# kube-prometheus-stack (Prometheus + Grafana)
#  - 클러스터와 애플리케이션 지표를 수집·시각화
#  - 알림은 CloudWatch 경보 쪽으로 일원화했으므로 Alertmanager는 비활성화
############################################################

resource "random_password" "grafana" {
  length  = 20
  special = false
}

resource "helm_release" "this" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = var.namespace
  create_namespace = true
  version          = var.chart_version

  # 노드가 2대뿐이라 리소스를 넉넉하게 잡지 않음
  values = [yamlencode({
    grafana = {
      adminPassword = random_password.grafana.result
      service       = { type = "ClusterIP" }
    }

    prometheus = {
      prometheusSpec = {
        retention = var.prometheus_retention
        resources = {
          requests = { cpu = "200m", memory = "512Mi" }
          limits   = { cpu = "500m", memory = "1Gi" }
        }
      }
    }

    alertmanager = { enabled = false }
  })]
}
