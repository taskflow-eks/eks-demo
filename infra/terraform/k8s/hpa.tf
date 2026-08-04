############################################################
# HPA (Horizontal Pod Autoscaler)
#  - CPU 사용률이 임계치를 넘으면 파드를 자동으로 늘린다
#  - metrics-server가 먼저 설치되어 있어야 동작한다
############################################################

resource "kubernetes_horizontal_pod_autoscaler_v2" "frontend" {
  metadata {
    name      = "${local.frontend_name}-hpa"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    min_replicas = var.replicas
    max_replicas = var.max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.frontend.metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = var.hpa_cpu_target
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "backend" {
  metadata {
    name      = "${local.backend_name}-hpa"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    min_replicas = var.replicas
    max_replicas = var.max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.backend.metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = var.hpa_cpu_target
        }
      }
    }
  }
}
