module "flux_operator_bootstrap" {
  source = "github.com/controlplaneio-fluxcd/terraform-kubernetes-flux-operator-bootstrap?ref=v0.9.0"

  revision = 1

  gitops_resources = {
    instance_yaml = file("${path.module}/../../../clusters/${var.cluster_name}/flux-system/flux-instance.yaml")
  }

  managed_resources = {
    secrets_yaml = <<-YAML
      apiVersion: v1
      kind: Secret
      metadata:
        name: flux-system
        namespace: flux-system
      type: Opaque
      stringData:
        username: ${var.github_username}
        password: ${var.github_token}
    YAML
  }

  debug_on_failure = true

  depends_on = [helm_release.metrics-server, talos_cluster_kubeconfig.kubeconfig]
}
