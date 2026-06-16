resource "vault_policy" "capi-reader" {
  name   = var.capi-sa-name
  policy = <<EOT
path "main/data/capi/*" {
  capabilities = ["read", "list"]
}
path "main/metadata/*" {
  capabilities = [ "list" ]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "capi-reader" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.capi-sa-name
  bound_service_account_names      = [var.capi-sa-name]
  bound_service_account_namespaces = ["proxmox-infrastructure-system"]
  token_policies                   = [vault_policy.capi-reader.name]
  token_ttl                        = 3600
}
