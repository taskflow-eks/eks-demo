output "role_arn" {
  description = "워크플로우의 role-to-assume 에 넣을 IAM 역할 ARN"
  value       = aws_iam_role.this.arn
}
