output "sns_topic_arn" {
  description = "경보가 발행되는 SNS 토픽"
  value       = aws_sns_topic.alerts.arn
}

output "alarm_names" {
  description = "생성된 경보 이름 목록"
  value = [
    aws_cloudwatch_metric_alarm.error_logs.alarm_name,
    aws_cloudwatch_metric_alarm.rds_cpu.alarm_name,
  ]
}
