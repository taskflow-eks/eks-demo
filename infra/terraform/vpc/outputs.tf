output "vpc_id" {
  description = "생성된 VPC ID"
  value       = module.this.vpc_id
}

output "public_subnets" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = module.this.public_subnets
}

output "private_subnets" {
  description = "프라이빗 서브넷 ID 목록"
  value       = module.this.private_subnets
}
