variable "bucket" {
  type = string
}

variable "access_key" {
  type      = string
  sensitive = true
}

variable "secret_key" {
  type      = string
  sensitive = true
}

variable "authentik-sa-name" {
  type    = string
  default = "authentik-reader"
}

variable "vault_address" {
  type    = string
  default = "https://vault.local.m1xxos.tech"
}
