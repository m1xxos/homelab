resource "vault_mount" "user-secrets" {
  path        = "user-secrets"
  type        = "kv"
  options     = { version = "2" }
  description = "User secret kv engine"
}