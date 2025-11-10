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
