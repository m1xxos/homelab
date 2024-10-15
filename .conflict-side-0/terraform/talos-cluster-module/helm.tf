resource "helm_release" "cilium_cni" {
  depends_on = [data.talos_cluster_kubeconfig.kubeconfig]
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"
  version    = "1.16.3"

  values = [
    "${file("cilium-values.yaml")}"
  ]
}

resource "helm_release" "metrics-server" {
  depends_on = [data.talos_cluster_kubeconfig.kubeconfig]
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  set {
    name = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}