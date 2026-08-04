output "repository_urls" {
  description = "레포지토리 이름 → URL"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "레포지토리 ARN 목록"
  value       = [for repo in aws_ecr_repository.this : repo.arn]
}
