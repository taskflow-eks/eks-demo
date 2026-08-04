############################################################
# AWS for Fluent Bit
#  - 노드에 흩어져 있는 컨테이너 로그를 CloudWatch 한 곳으로 모음
#  - 로그 그룹을 Terraform이 만들어 보관 기간을 코드로 관리
#    (차트의 autoCreateGroup을 끄는 이유)
############################################################

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_policy" "this" {
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

module "irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "${var.project_name}-fluent-bit-irsa"

  role_policy_arns = {
    logs = aws_iam_policy.this.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.service_account_name}"]
    }
  }
}

resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = module.irsa.iam_role_arn
    }
  }
}

resource "helm_release" "this" {
  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  namespace  = var.namespace
  version    = var.chart_version

  values = [yamlencode({
    serviceAccount = {
      create = false
      name   = kubernetes_service_account_v1.this.metadata[0].name
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
    kubernetes_service_account_v1.this,
    aws_cloudwatch_log_group.application,
  ]
}
