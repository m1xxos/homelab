resource "random_string" "authentik-secret-key" {
  length = 60
  min_numeric = 10
  min_special = 10
  min_upper = 10
}

resource "vault_mount" "main" {
  path        = "main"
  type        = "kv"
  options     = { version = "2" }
  description = "main cluster kv engine"
}

resource "vault_kv_secret_v2" "authentik-secret-key" {
  mount = vault_mount.main.path
  name = "authentik/secret-key"
  data_json = jsonencode({
    secret-key = random_string.authentik-secret-key.result
  }
  )
}
