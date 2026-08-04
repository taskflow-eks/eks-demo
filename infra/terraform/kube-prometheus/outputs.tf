output "grafana_admin_password" {
  description = "Grafana admin 계정 비밀번호"
  value       = random_password.grafana.result
  sensitive   = true
}

output "grafana_service" {
  description = "port-forward 대상 서비스 이름"
  value       = "svc/kube-prometheus-stack-grafana"
}
