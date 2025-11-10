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

variable "vault_token" {
  type = string
  sensitive = true
}

variable "authentik-sa-name" {
  type = string
  default = "authentik-reader"
}
