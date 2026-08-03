############################################
# 장애 감지 → 알림 파이프라인
#  로그 수집(Fluent Bit) → CloudWatch 지표 필터 → 경보 → SNS → Lambda → Discord
############################################

locals {
  notification_enabled = var.discord_webhook_url != ""
  metric_namespace     = "${var.project_name}/Application"
}

# 애플리케이션 로그에서 ERROR 를 세어 지표로 변환
resource "aws_cloudwatch_log_metric_filter" "error_logs" {
  name           = "${var.project_name}-error-logs"
  log_group_name = aws_cloudwatch_log_group.application.name
  pattern        = "ERROR"

  metric_transformation {
    name          = "ErrorLogCount"
    namespace     = local.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_sns_topic" "alerts" {
  count = local.notification_enabled ? 1 : 0
  name  = "${var.project_name}-alerts"
}

# --- 경보 ------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "error_logs" {
  count = local.notification_enabled ? 1 : 0

  alarm_name        = "${var.project_name}-error-logs"
  alarm_description = "애플리케이션 로그에서 ERROR가 감지되었습니다."

  namespace           = local.metric_namespace
  metric_name         = aws_cloudwatch_log_metric_filter.error_logs.metric_transformation[0].name
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts[0].arn]
  ok_actions    = [aws_sns_topic.alerts[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count = local.notification_enabled ? 1 : 0

  alarm_name        = "${var.project_name}-rds-cpu-high"
  alarm_description = "RDS CPU 사용률이 80%를 초과했습니다."

  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }

  alarm_actions = [aws_sns_topic.alerts[0].arn]
  ok_actions    = [aws_sns_topic.alerts[0].arn]
}

# --- Lambda (Discord 전송) --------------------------------------------------

data "archive_file" "discord_notify" {
  count = local.notification_enabled ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/discord_notify.py"
  output_path = "${path.module}/.build/discord_notify.zip"
}

resource "aws_iam_role" "discord_notify" {
  count = local.notification_enabled ? 1 : 0

  name = "${var.project_name}-discord-notify-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "discord_notify_basic" {
  count = local.notification_enabled ? 1 : 0

  role       = aws_iam_role.discord_notify[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "discord_notify" {
  count = local.notification_enabled ? 1 : 0

  function_name = "${var.project_name}-discord-notify"
  role          = aws_iam_role.discord_notify[0].arn

  filename         = data.archive_file.discord_notify[0].output_path
  source_code_hash = data.archive_file.discord_notify[0].output_base64sha256

  runtime = "python3.12"
  handler = "discord_notify.handler"
  timeout = 15

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }
}

resource "aws_cloudwatch_log_group" "discord_notify" {
  count = local.notification_enabled ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.discord_notify[0].function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_permission" "sns_invoke" {
  count = local.notification_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.discord_notify[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts[0].arn
}

resource "aws_sns_topic_subscription" "discord" {
  count = local.notification_enabled ? 1 : 0

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.discord_notify[0].arn
}
