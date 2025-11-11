resource "vault_policy" "authentik-reader" {
  name   = var.authentik-sa-name
  policy = <<EOT
path "main/data/authentik/*" {
  capabilities = ["read", "list"]
}
path "main/metadata/*" {
  capabilities = [ "list" ]
}
EOT
}

resource "vault_policy" "users-reader" {
  name   = ""
  policy = <<EOT
path "user-secrets/data/*" {
  capabilities = ["read", "list"]
}
path "user-secrets/metadata/*" {
  capabilities = [ "list" ]
}
EOT
}
