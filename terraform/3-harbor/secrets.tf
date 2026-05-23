# Store robot account credentials in Vault for use by CI/CD
resource "vault_kv_secret_v2" "harbor_robot" {
  mount = "general"
  name  = "harbor/robot-terraform"
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
    docker_hub = harbor_registry.dockerhub.endpoint_url
    quay_io    = harbor_registry.quay.endpoint_url
    ghcr_io    = harbor_registry.ghcr.endpoint_url
    k8s        = harbor_registry.k8s_gcr.endpoint_url
    mcr        = harbor_registry.mcr.endpoint_url
    gcr        = harbor_registry.gcr.endpoint_url
  })
}
