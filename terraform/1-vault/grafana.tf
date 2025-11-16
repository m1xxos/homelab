resource "vault_policy" "grafana-reader" {
  name   = var.grafana-sa-name
  policy = <<EOT
path "main/data/grafana/*" {
  capabilities = ["read", "list"]
}
path "main/metadata/*" {
  capabilities = [ "list" ]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "grafana-reader" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.grafana-sa-name
  bound_service_account_names      = [var.grafana-sa-name]
  bound_service_account_namespaces = ["monitoring"]
  token_policies                   = [vault_policy.grafana-reader.name]
  token_ttl                        = 3600
}
