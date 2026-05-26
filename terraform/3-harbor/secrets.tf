# Store robot account credentials in Vault for use by CI/CD
resource "vault_kv_secret_v2" "harbor_robot" {
  mount = "general"
  name  = "harbor/robot-k8s"
  data_json = jsonencode({
    name   = harbor_robot_account.terraform.name
    secret = harbor_robot_account.terraform.secret
  })
}

# Store proxy registries configuration
resource "vault_kv_secret_v2" "harbor_proxy_registries" {
  mount = "general"
  name  = "harbor/proxy-registries"
  data_json = jsonencode({
    docker_hub = "${var.harbor_url}/${harbor_project.dockerhub_proxy.name}"
    quay_io    = "${var.harbor_url}/${harbor_project.quay_proxy.name}"
    ghcr_io    = "${var.harbor_url}/${harbor_project.ghcr_proxy.name}"
    k8s        = "${var.harbor_url}/${harbor_project.k8s_gcr_proxy.name}"
    mcr        = "${var.harbor_url}/${harbor_project.mcr_proxy.name}"
    gcr        = "${var.harbor_url}/${harbor_project.gcr_proxy.name}"
  })
}
