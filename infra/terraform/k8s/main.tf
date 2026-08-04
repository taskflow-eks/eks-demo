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

    # Pod Readiness Gate
    # 파드가 Ready 조건을 만족해도, ALB 대상 그룹에 등록되어 헬스체크를 통과하기
    # 전까지는 Ready로 취급하지 않는다. 이 라벨이 없으면 롤링 업데이트 중
    # 새 파드가 아직 ALB에 등록되지 않은 상태에서 옛 파드가 제거되어 502가 발생한다.
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
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

        # preStop 대기(아래)가 끝날 때까지 강제 종료되지 않도록 여유를 둔다
        termination_grace_period_seconds = var.termination_grace_seconds

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

          # 종료 신호를 받은 뒤에도 잠시 요청을 계속 받는다.
          # ALB가 이 파드를 대상 그룹에서 제거하는 데 시간이 걸리므로,
          # 곧바로 죽으면 그 사이 들어온 요청이 502가 된다.
          lifecycle {
            pre_stop {
              exec {
                command = ["/bin/sh", "-c", "sleep ${var.pre_stop_sleep_seconds}"]
              }
            }
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
        termination_grace_period_seconds = var.termination_grace_seconds

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

          # ALB가 대상 그룹에서 제거할 시간을 벌어준 뒤 Nginx를 정상 종료한다
          lifecycle {
            pre_stop {
              exec {
                command = ["/bin/sh", "-c", "sleep ${var.pre_stop_sleep_seconds}; nginx -s quit"]
              }
            }
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

      # 헬스체크를 촘촘히 해 새 파드가 빨리 정상으로 인식되도록 한다
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "10"
      "alb.ingress.kubernetes.io/healthy-threshold-count"      = "2"

      # 등록 해제 대기는 기본 300초. preStop 대기 시간에 맞춰 줄인다
      "alb.ingress.kubernetes.io/target-group-attributes" = "deregistration_delay.timeout_seconds=${var.deregistration_delay_seconds}"
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
