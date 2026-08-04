output "log_group_name" {
  description = "애플리케이션 로그가 모이는 CloudWatch 로그 그룹"
  value       = aws_cloudwatch_log_group.application.name
}
