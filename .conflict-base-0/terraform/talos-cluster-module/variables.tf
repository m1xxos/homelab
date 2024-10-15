
variable "cluster_name" {
  type    = string
  default = "homelab"
}

variable "default_gateway" {
  type    = string
  default = "192.168.1.1"
}

variable "talos_cps" {
  type = list(object({
    name  = string
    vm_id = number
    ip    = string
  }))
}

variable "talos_workers" {
  type = list(object({
    name  = string
    vm_id = number
    ip    = string
  }))
}

variable "talos_image_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type      = string
  sensitive = true
}
