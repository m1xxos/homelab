ephemeral "vault_kv_secret_v2" "authentik_token" {
  name  = "authentik-m1xxos"
  mount = "user-secrets"
}

ephemeral "vault_kv_secret_v2" "github-oauth" {
  name  = "authentik-m1xxos"
  mount = "github-oauth"
}
