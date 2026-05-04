resource "terraform_data" "flux_git_auth_checksum" {
  input = sha256(nonsensitive(var.github_token))
}

resource "flux_bootstrap_git" "cluster" {
  depends_on = [helm_release.metrics-server, talos_cluster_kubeconfig.kubeconfig]

  embedded_manifests = true
  path               = "clusters/${var.cluster_name}"

  lifecycle {
    replace_triggered_by = [terraform_data.flux_git_auth_checksum]
  }
}
