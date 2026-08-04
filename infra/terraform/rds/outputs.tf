output "endpoint" {
  description = "RDS 접속 주소"
  value       = aws_db_instance.this.address
}

output "db_identifier" {
  description = "CloudWatch 경보 차원에 사용할 DB 식별자"
  value       = aws_db_instance.this.identifier
}

output "secret_arn" {
  description = "자격증명 시크릿 ARN (IRSA 권한 범위에 사용)"
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  description = "자격증명 시크릿 이름"
  value       = aws_secretsmanager_secret.this.name
}

output "security_group_id" {
  description = "RDS 보안 그룹"
  value       = aws_security_group.this.id
}
