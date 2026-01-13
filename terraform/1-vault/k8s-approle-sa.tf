resource "vault_auth_backend" "general" {
  type = "approle"
}

resource "vault_approle_auth_backend_role" "general" {
  backend               = vault_auth_backend.general.path
  role_name             = "general-k8s"
  token_policies        = ["default", "general-reader"]
  bind_secret_id        = false
  token_bound_cidrs     = ["192.168.1.0/24"]
  secret_id_bound_cidrs = ["192.168.1.0/24"]
  token_max_ttl         = 600
}
