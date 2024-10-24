resource "flux_bootstrap_git" "this" {
  depends_on = [helm_release.metrics-server]

  embedded_manifests = true
  path               = "clusters/${var.cluster_name}"
}