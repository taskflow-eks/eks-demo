############################################################
# 장애 감지
#  - 애플리케이션 로그에서 ERROR를 세어 지표로 변환하고 경보를 건다
#  - 경보는 SNS로 발행되며, 실제 전달은 lambda 모듈이 담당
############################################################

locals {
  metric_namespace = "${var.project_name}/Application"
}

resource "aws_cloudwatch_log_metric_filter" "error_logs" {
  name           = "${var.project_name}-error-logs"
  log_group_name = var.log_group_name
  pattern        = var.error_pattern

  metric_transformation {
    name          = "ErrorLogCount"
    namespace     = local.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_cloudwatch_metric_alarm" "error_logs" {
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

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name        = "${var.project_name}-rds-cpu-high"
  alarm_description = "RDS CPU 사용률이 ${var.rds_cpu_threshold}%를 초과했습니다."

  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.rds_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
