output "namespace" {
  description = "생성된 네임스페이스 이름"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "backend_role_arn" {
  description = "백엔드 서비스 어카운트에 연결된 IAM 역할"
  value       = module.backend_irsa.iam_role_arn
}
