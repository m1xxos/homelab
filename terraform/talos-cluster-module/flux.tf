resource "flux_bootstrap_git" "cluster" {
  depends_on = [helm_release.metrics-server]

  embedded_manifests = true
  path               = "clusters/${var.cluster_name}"
}