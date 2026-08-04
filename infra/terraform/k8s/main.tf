############################################################
# 애플리케이션 워크로드
#  - 네임스페이스, 백엔드 IRSA, Deployment / Service / Ingress
#  - Ingress가 생성되면 AWS Load Balancer Controller가 ALB를 만든다
#    (ALB는 Terraform이 직접 만드는 리소스가 아니라 컨트롤러가 만든다)
############################################################

locals {
  frontend_name = "${var.project_name}-frontend"
  backend_name  = "${var.project_name}-backend"
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

# --- 백엔드 IRSA -------------------------------------------------------------
# 파드에 액세스 키를 넣지 않고, 서비스 어카운트에 IAM 역할을 연결한다.
# 권한 범위는 DB 자격증명 시크릿 하나로 제한한다.

resource "aws_iam_policy" "backend_secrets" {
  name = "${var.project_name}-backend-secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      Resource = var.db_secret_arn
    }]
  })
}

module "backend_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "${var.project_name}-backend-irsa"

  role_policy_arns = {
    secrets = aws_iam_policy.backend_secrets.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.backend_service_account}"]
    }
  }
}

resource "kubernetes_service_account_v1" "backend" {
  metadata {
    name      = var.backend_service_account
    namespace = kubernetes_namespace_v1.this.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = module.backend_irsa.iam_role_arn
    }
  }
}

# --- 백엔드 ------------------------------------------------------------------

resource "kubernetes_deployment_v1" "backend" {
  metadata {
    name      = local.backend_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = local.backend_name }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = local.backend_name }
    }

    template {
      metadata {
        labels = { app = local.backend_name }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.backend.metadata[0].name

        # 파드를 두 가용영역에 고르게 배치해 한쪽 AZ 장애에도 요청 처리가 이어지도록 함
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "ScheduleAnyway"

          label_selector {
            match_labels = { app = local.backend_name }
          }
        }

        container {
          name  = local.backend_name
          image = "${var.ecr_registry}/${local.backend_name}:${var.backend_image_tag}"

          port {
            container_port = var.backend_port
          }

          env {
            name  = "DB_SECRET_NAME"
            value = var.db_secret_name
          }

          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "250m", memory = "256Mi" }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = var.backend_port
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = var.backend_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }

  # 이미지 태그는 배포 파이프라인이 kubectl set image 로 바꾸므로
  # Terraform이 되돌리지 않도록 제외한다
  lifecycle {
    ignore_changes = [spec[0].template[0].spec[0].container[0].image]
  }

  wait_for_rollout = false
}

resource "kubernetes_service_v1" "backend" {
  metadata {
    name      = "${local.backend_name}-svc"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    selector = { app = local.backend_name }
    type     = "ClusterIP"

    port {
      port        = 80
      target_port = var.backend_port
    }
  }
}

# --- 프론트엔드 ---------------------------------------------------------------

resource "kubernetes_deployment_v1" "frontend" {
  metadata {
    name      = local.frontend_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = local.frontend_name }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = local.frontend_name }
    }

    template {
      metadata {
        labels = { app = local.frontend_name }
      }

      spec {
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "ScheduleAnyway"

          label_selector {
            match_labels = { app = local.frontend_name }
          }
        }

        container {
          name  = local.frontend_name
          image = "${var.ecr_registry}/${local.frontend_name}:${var.frontend_image_tag}"

          port {
            container_port = 80
          }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "250m", memory = "256Mi" }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [spec[0].template[0].spec[0].container[0].image]
  }

  wait_for_rollout = false
}

resource "kubernetes_service_v1" "frontend" {
  metadata {
    name      = "${local.frontend_name}-svc"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    selector = { app = local.frontend_name }
    type     = "ClusterIP"

    port {
      port        = 80
      target_port = 80
    }
  }
}

# --- Ingress (ALB 생성 트리거) ------------------------------------------------

resource "kubernetes_ingress_v1" "this" {
  metadata {
    name      = "${var.project_name}-ingress"
    namespace = kubernetes_namespace_v1.this.metadata[0].name

    annotations = {
      "alb.ingress.kubernetes.io/load-balancer-name" = "${var.project_name}-alb"
      "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"   = "/"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.frontend.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  # ALB가 프로비저닝되어 주소가 할당될 때까지 기다린다
  wait_for_load_balancer = true

  depends_on = [kubernetes_service_v1.frontend]
}
