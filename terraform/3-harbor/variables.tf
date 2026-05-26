variable "bucket" {
  type      = string
  sensitive = true
}

variable "access_key" {
  type      = string
  sensitive = true
}

variable "secret_key" {
  type      = string
  sensitive = true
}

variable "vault_address" {
  type    = string
  default = "https://vault.local.m1xxos.online"
}

variable "harbor_url" {
  type    = string
  default = "https://harbor.local.m1xxos.online"
}
