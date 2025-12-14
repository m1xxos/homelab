resource "helm_release" "cilium_cni" {
  depends_on = [talos_cluster_kubeconfig.kubeconfig]
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"
  version    = var.cilium_version

  values = [
    file("${path.module}/cilium-values.yaml")
  ]
}

resource "helm_release" "metrics-server" {
  depends_on = [talos_cluster_kubeconfig.kubeconfig, helm_release.cilium_cni]
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.metrics_server_version

  set = [
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    }
  ]
}

resource "helm_release" "talos_ccm" {
  depends_on = [talos_cluster_kubeconfig.kubeconfig, helm_release.cilium_cni]
  name       = "talos-ccm"
  chart      = "oci://ghcr.io/siderolabs/charts/talos-cloud-controller-manager"
  namespace  = "kube-system"
  version    = var.talos_ccm_version
  set_list = [{
    name  = "enabledControllers"
    value = ["cloud-node", "cloud-node-lifecycle", "node-csr-approval"]
  }]
}
