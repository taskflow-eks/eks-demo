output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "update_kubeconfig_command" {
  description = "kubectl 설정 명령어"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_registry" {
  description = "GitHub Actions Secret(AWS_ACCOUNT_ID)로 조합되는 레지스트리 주소"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "alb_dns_name" {
  description = "Ingress가 만든 ALB 주소. 브라우저로 접속할 곳"
  value       = module.k8s.alb_dns_name
}

output "application_url" {
  description = "서비스 접속 URL"
  value       = module.k8s.alb_dns_name != null ? "http://${module.k8s.alb_dns_name}" : null
}

# --- 아래 출력값은 main.tf에서 해당 모듈의 주석을 해제한 뒤 함께 활성화할 것 -----

# output "ecr_repository_urls" {
#   description = "레포지토리 이름 → URL"
#   value       = module.ecr.repository_urls
# }

# output "rds_endpoint" {
#   description = "RDS 접속 주소"
#   value       = module.rds.endpoint
# }

# output "db_secret_name" {
#   description = "백엔드가 읽는 DB 자격증명 시크릿 이름"
#   value       = module.rds.secret_name
# }

# output "bastion_public_ip" {
#   description = "Bastion 퍼블릭 IP"
#   value       = module.bastion.public_ip
# }

# output "bastion_ssm_command" {
#   description = "키페어 없이 Bastion에 접속하는 명령어"
#   value       = "aws ssm start-session --target ${module.bastion.instance_id} --region ${var.aws_region}"
# }

# output "application_log_group" {
#   description = "애플리케이션 로그가 모이는 CloudWatch 로그 그룹"
#   value       = module.fluentbit.log_group_name
# }

# output "grafana_admin_password" {
#   description = "Grafana admin 비밀번호"
#   value       = var.enable_monitoring_stack ? module.kube_prometheus[0].grafana_admin_password : null
#   sensitive   = true
# }

# output "grafana_port_forward_command" {
#   description = "Grafana 접속용 port-forward 명령어"
#   value       = var.enable_monitoring_stack ? "kubectl port-forward -n monitoring ${module.kube_prometheus[0].grafana_service} 3000:80" : null
# }

# output "github_actions_role_arn" {
#   description = "워크플로우의 role-to-assume 에 넣을 IAM 역할 ARN"
#   value       = local.oidc_enabled ? module.github_oidc[0].role_arn : null
# }

# output "sns_alert_topic_arn" {
#   description = "경보가 발행되는 SNS 토픽"
#   value       = local.notification_enabled ? module.monitoring[0].sns_topic_arn : null
# }
