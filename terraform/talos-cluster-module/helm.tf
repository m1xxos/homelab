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