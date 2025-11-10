resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "main" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc:443"
}

resource "vault_kubernetes_auth_backend_role" "authentik-reader" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.authentik-sa-name
  bound_service_account_names      = [var.authentik-sa-name]
  bound_service_account_namespaces = ["authentik"]
  token_policies                   = [vault_policy.authentik-reader.name]
  token_ttl                        = 3600
}
