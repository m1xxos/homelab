resource "vault_policy" "minio-reader" {
  name   = var.minio-sa-name
  policy = <<EOT
path "main/data/minio/*" {
  capabilities = ["read", "list"]
}
path "main/metadata/*" {
  capabilities = [ "list" ]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "minio-reader" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.minio-sa-name
  bound_service_account_names      = [var.minio-sa-name]
  bound_service_account_namespaces = ["default"]
  token_policies                   = [vault_policy.minio-reader.name]
  token_ttl                        = 3600
}
