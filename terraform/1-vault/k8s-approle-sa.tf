resource "vault_auth_backend" "general" {
  path = "cluster-general"
  type = "approle"
}

resource "vault_approle_auth_backend_role" "general" {
  backend               = vault_auth_backend.general.path
  role_name             = "cluster-general-reader"
  token_policies        = ["default", "general-reader"]
  token_bound_cidrs     = ["192.168.1.0/24", "10.244.0.0/16", "10.168.0.0/16"]
  secret_id_bound_cidrs = ["192.168.1.0/24", "10.244.0.0/16", "10.168.0.0/16"]
  token_max_ttl         = 600
}
