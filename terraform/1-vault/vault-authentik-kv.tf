resource "random_string" "authentik-secret-key" {
  length = 60
  min_numeric = 10
  min_special = 10
  min_upper = 10
}

resource "vault_mount" "authentik" {
  path        = "authentik"
  type        = "kv"
  options     = { version = "2" }
  description = "authentik kv engine"
}

resource "vault_kv_secret_v2" "authentik-secret-key" {
  mount = vault_mount.authentik.path
  name = "secret-key"
  data_json = jsonencode({
    secret-key = random_string.authentik-secret-key.result
  }
  )
}