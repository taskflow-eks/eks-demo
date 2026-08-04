############################################################
# metrics-server
#  - EKS에는 기본 설치되지 않는다
#  - HPA가 CPU 사용률을 읽으려면 metrics.k8s.io API가 필요하다
############################################################

resource "helm_release" "this" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.chart_version
}
