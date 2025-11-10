resource "vault_policy" "authentik-reader" {
  name   = var.authentik-sa-name
  policy = <<EOT
path "main/authentik/*" {
  capabilities = [ "list", "read" ]
}
EOT
}
