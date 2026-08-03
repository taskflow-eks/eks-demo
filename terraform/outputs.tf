output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_urls" {
  value = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "ecr_registry" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "rds_endpoint" {
  value = aws_db_instance.this.address
}

output "db_secret_name" {
  value = aws_secretsmanager_secret.db.name
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "application_log_group" {
  value = aws_cloudwatch_log_group.application.name
}

output "grafana_admin_password" {
  value     = var.enable_monitoring_stack ? random_password.grafana[0].result : null
  sensitive = true
}

output "grafana_port_forward_command" {
  value = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
}

output "github_actions_role_arn" {
  value = local.oidc_enabled ? aws_iam_role.github_actions[0].arn : null
}
