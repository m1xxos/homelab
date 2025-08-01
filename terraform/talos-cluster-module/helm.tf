resource "helm_release" "cilium_cni" {
  depends_on = [data.talos_cluster_kubeconfig.kubeconfig]
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"
  version    = "1.18.0"

  values = [
    "${file("cilium-values.yaml")}"
  ]
}

resource "helm_release" "metrics-server" {
  depends_on = [data.talos_cluster_kubeconfig.kubeconfig, helm_release.cilium_cni]
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.13.0"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}