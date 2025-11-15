data "vault_kv_secret_v2" "authentik-auth" {
  name = "authentik-auth"
  mount = "user-secrets"
}
