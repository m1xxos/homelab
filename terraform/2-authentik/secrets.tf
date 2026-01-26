ephemeral "vault_kv_secret_v2" "authentik_token" {
  name  = "authentik-m1xxos"
  mount = "user-secrets"
}

data "vault_kv_secret_v2" "github-oauth" {
  name  = "github-oauth"
  mount = "user-secrets"
}
