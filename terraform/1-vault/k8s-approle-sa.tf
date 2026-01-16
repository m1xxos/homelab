resource "vault_auth_backend" "general" {
  path = "cluster-general"
  type = "approle"
}

resource "vault_approle_auth_backend_role" "general" {
  backend               = vault_auth_backend.general.path
  role_name             = "cluster-general-reader"
  token_policies        = ["default", "general-reader"]
  token_bound_cidrs     = ["192.168.1.0/24"]
  secret_id_bound_cidrs = ["192.168.1.0/24"]
  token_max_ttl         = 600
}

resource "vault_approle_auth_backend_role_secret_id" "general" {
  role_name = vault_approle_auth_backend_role.general.role_name
}
