output "security_group_id" {
  description = "Bastion 보안 그룹 (RDS 인바운드 허용에 사용)"
  value       = aws_security_group.this.id
}

output "public_ip" {
  description = "Bastion 퍼블릭 IP"
  value       = aws_instance.this.public_ip
}

output "instance_id" {
  description = "SSM 접속에 사용할 인스턴스 ID"
  value       = aws_instance.this.id
}
