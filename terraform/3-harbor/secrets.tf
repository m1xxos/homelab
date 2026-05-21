# Store robot account credentials in Vault for use by CI/CD
resource "vault_kv_secret_v2" "harbor_robot" {
  mount = "main"
  name  = "harbor/robot-terraform"
  data_json = jsonencode({
    name   = harbor_robot_account.terraform.name
    secret = harbor_robot_account.terraform.secret
  })
}

# Store proxy registries configuration
resource "vault_kv_secret_v2" "harbor_proxy_registries" {
  mount = "main"
  name  = "harbor/proxy-registries"
  data_json = jsonencode({
    docker_hub  = harbor_registry.dockerhub.url
    quay_io     = harbor_registry.quay.url
    ghcr_io     = harbor_registry.ghcr.url
    k8s         = harbor_registry.k8s_gcr.url
    bitnami     = harbor_registry.bitnami.url
    jetbrains   = harbor_registry.jetbrains.url
    mcr         = harbor_registry.mcr.url
  })
}
