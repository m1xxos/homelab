resource "vault_mount" "general" {
  path        = "general"
  type        = "kv"
  options     = { version = "2" }
  description = "general clusters kv engine"
}

resource "vault_kv_secret_v2" "cloudflare-secret-key" {
  mount = vault_mount.general.path
  name  = "cloudflare-api-token"
  data_json = jsonencode({
    api-token = var.cloudflare_api_token
    }
  )
}

resource "random_password" "dragonfly-gl-password" {
  length      = 60
  min_numeric = 10
  min_special = 10
  min_upper   = 10
}

resource "vault_kv_secret_v2" "dragonfly-gl-password" {
  mount = vault_mount.general.path
  name  = "dragonfly-gl-password"
  data_json = jsonencode({
    password = random_password.dragonfly-gl-password.result
    }
  )
}

resource "random_string" "gitlab-s3-access-key" {
  length  = 20
  special = false
  upper   = true
  lower   = false
  numeric = true
}

resource "random_password" "gitlab-s3-secret-key" {
  length           = 40
  special          = true
  override_special = "/+"
}

resource "vault_kv_secret_v2" "gitlab-object-storage" {
  mount = vault_mount.general.path
  name  = "gitlab-object-storage"
  data_json = jsonencode({
    aws_access_key_id     = random_string.gitlab-s3-access-key.result
    aws_secret_access_key = random_password.gitlab-s3-secret-key.result
    bucket_region         = "us-east-1"
  })
}

resource "vault_policy" "general-reader" {
  name   = "general-reader"
  policy = <<EOT
path "general/data/*" {
  capabilities = ["create", "update", "read", "list", "delete"]
}
path "general/metadata/*" {
  capabilities = ["create", "update", "read", "list", "delete"]
}
path "general/data/clustermesh/*" {
  capabilities = ["create", "update", "read", "list", "delete"]
}
path "general/metadata/clustermesh/*" {
  capabilities = ["create", "update", "read", "list", "delete"]
}
EOT
}
