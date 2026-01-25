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
