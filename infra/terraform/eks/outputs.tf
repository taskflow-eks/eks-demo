output "cluster_name" {
  description = "클러스터 이름"
  value       = module.this.cluster_name
}

output "cluster_arn" {
  description = "클러스터 ARN"
  value       = module.this.cluster_arn
}

output "cluster_endpoint" {
  description = "API 서버 엔드포인트"
  value       = module.this.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "API 서버 인증서 (base64)"
  value       = module.this.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "IRSA에 사용할 OIDC 공급자 ARN"
  value       = module.this.oidc_provider_arn
}

output "node_security_group_id" {
  description = "워커 노드 보안 그룹 (RDS 인바운드 허용에 사용)"
  value       = module.this.node_security_group_id
}
