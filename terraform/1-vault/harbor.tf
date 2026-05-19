resource "random_password" "harbor-admin-password" {
  length      = 60
  min_numeric = 10
  min_special = 10
  min_upper   = 10
}

resource "vault_kv_secret_v2" "harbor-admin" {
  mount = vault_mount.main.path
  name  = "harbor/admin"
  data_json = jsonencode({
    password = random_password.harbor-admin-password.result
    }
  )
}

resource "random_password" "harbor-core-secret-key" {
  length      = 16
  min_numeric = 4
  min_special = 4
  min_upper   = 4
}

resource "vault_kv_secret_v2" "harbor-core" {
  mount = vault_mount.main.path
  name  = "harbor/core"
  data_json = jsonencode({
    secretKey = random_password.harbor-core-secret-key.result
    }
  )
}
