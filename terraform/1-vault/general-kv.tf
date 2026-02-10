resource "vault_mount" "general" {
  path        = "general"
  type        = "kv"
  options     = { version = "2" }
  description = "general clusters kv engine"
}

resource "vault_kv_secret_v2" "cloudflare-secret-key" {
  mount = vault_mount.general.path
  name  = "cloudflare-api-token"
  data_json = jsonencode({
    api-token = var.cloudflare_api_token
    }
  )
}

resource "vault_policy" "general-reader" {
  name   = "general-reader"
  policy = <<EOT
path "general/data/*" {
  capabilities = ["read", "list"]
}
path "general/metadata/*" {
  capabilities = [ "list" ]
}
path "general/data/clustermesh/*" {
  capabilities = ["create", "update", "read", "list", "delete"]
}
path "general/metadata/clustermesh/*" {
  capabilities = ["create", "update", "read", "list", "delete"]
}
EOT
}
