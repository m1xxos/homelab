resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "main" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc:443"
}

resource "vault_kubernetes_auth_backend_role" "authentik-reader" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.authentik-sa-name
  bound_service_account_names      = [var.authentik-sa-name]
  bound_service_account_namespaces = ["authentik"]
  token_policies                   = [vault_policy.authentik-reader.name]
  token_ttl                        = 3600
}

resource "vault_jwt_auth_backend" "oidc" {
  description        = "Authentik OIDC"
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "https://authentik.local.m1xxos.tech/application/o/vault/"
  oidc_client_id     = data.vault_kv_secret_v2.authentik-auth.data.oidc_client_id
  oidc_client_secret = data.vault_kv_secret_v2.authentik-auth.data.oidc_client_secret
  default_role       = "reader"
  jwt_supported_algs = [ "RS256", "RS384", "RS512", "ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "EdDSA"]
}

resource "vault_jwt_auth_backend_role" "name" {
  backend         = vault_jwt_auth_backend.oidc.path
  role_name       = "reader"
  user_claim      = "sub"
  bound_audiences = [ data.vault_kv_secret_v2.authentik-auth.data.oidc_client_id ]
  allowed_redirect_uris = [
    "${var.vault_address}/ui/vault/auth/oidc/oidc/callback",
    "${var.vault_address}/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]
  token_policies = [vault_policy.users-reader.name, vault_policy.authentik-reader.name]
}
