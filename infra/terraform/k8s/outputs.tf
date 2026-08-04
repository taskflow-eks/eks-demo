output "namespace" {
  description = "생성된 네임스페이스 이름"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "backend_role_arn" {
  description = "백엔드 서비스 어카운트에 연결된 IAM 역할"
  value       = module.backend_irsa.iam_role_arn
}

output "deployment_names" {
  description = "배포 파이프라인이 kubectl set image 대상으로 사용할 Deployment 이름"
  value = {
    frontend = kubernetes_deployment_v1.frontend.metadata[0].name
    backend  = kubernetes_deployment_v1.backend.metadata[0].name
  }
}

output "alb_dns_name" {
  description = "Ingress에 할당된 ALB 주소"
  value       = try(kubernetes_ingress_v1.this.status[0].load_balancer[0].ingress[0].hostname, null)
}
