resource "flux_bootstrap_git" "cluster" {
  depends_on = [helm_release.metrics-server, talos_cluster_kubeconfig.kubeconfig]

  embedded_manifests = true
  path               = "clusters/${var.cluster_name}"
}