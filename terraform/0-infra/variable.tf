variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type      = string
  sensitive = true
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true

}

variable "ssh_password" {
  type      = string
  sensitive = true
}

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

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type      = string
  sensitive = true
}

variable "authentik_token" {
  type      = string
  sensitive = true
}
variable "github_token" {
  type      = string
  sensitive = true
}

variable "infisical_id" {
  type      = string
  sensitive = true
}

variable "infisical_secret" {
  type      = string
  sensitive = true
}

variable "infisical_workspace_id" {
  type = string
  default = "cc160c9f-8470-482f-a8da-350d68337f48"
}
