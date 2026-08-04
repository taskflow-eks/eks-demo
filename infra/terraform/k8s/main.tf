############################################################
# 애플리케이션 네임스페이스 · 백엔드 IRSA
#  - 파드에 액세스 키를 넣지 않고, 서비스 어카운트에 IAM 역할을 연결
#  - 권한 범위는 DB 자격증명 시크릿 하나로 제한
############################################################

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

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
