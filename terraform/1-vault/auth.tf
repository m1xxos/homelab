resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "main" {
  backend = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://$KUBERNETES_PORT_443_TCP_ADDR:443"
}
