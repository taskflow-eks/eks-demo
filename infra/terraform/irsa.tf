############################################
# IRSA (IAM Roles for Service Accounts)
#  - 파드에 액세스 키를 넣지 않고, 서비스 어카운트에 IAM 역할을 연결
############################################

# --- 백엔드: Secrets Manager 읽기 권한 ------------------------------------

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
      Resource = aws_secretsmanager_secret.db.arn
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
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.k8s_namespace}:${var.backend_service_account}"]
    }
  }
}

# --- AWS Load Balancer Controller ------------------------------------------

module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                              = "${var.project_name}-alb-controller-irsa"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "kubernetes_service_account_v1" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = module.alb_controller_irsa.iam_role_arn
    }
  }

  depends_on = [module.eks]
}

# --- Fluent Bit: CloudWatch Logs 전송 권한 ---------------------------------

resource "aws_iam_policy" "fluent_bit" {
  name = "${var.project_name}-fluent-bit"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:CreateLogGroup",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:PutLogEvents",
        "logs:PutRetentionPolicy",
      ]
      Resource = "*"
    }]
  })
}

module "fluent_bit_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "${var.project_name}-fluent-bit-irsa"

  role_policy_arns = {
    logs = aws_iam_policy.fluent_bit.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-for-fluent-bit"]
    }
  }
}

resource "kubernetes_service_account_v1" "fluent_bit" {
  metadata {
    name      = "aws-for-fluent-bit"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.fluent_bit_irsa.iam_role_arn
    }
  }

  depends_on = [module.eks]
}
