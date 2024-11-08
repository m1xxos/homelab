
variable "cluster_name" {
  type    = string
  default = "homelab"
}

variable "default_gateway" {
  type    = string
  default = "192.168.1.1"
}

variable "external_ip" {
  type    = string
  default = "192.168.1.250"
}

variable "cp_cpu_cores" {
  type    = number
  default = 4
}

variable "cp_memory" {
  type    = number
  default = 4096
}

variable "cp_disk_size" {
  type    = number
  default = 20
}

variable "worker_cpu_cores" {
  type    = number
  default = 4
}

variable "worker_memory" {
  type    = number
  default = 4096
}

variable "worker_disk_size" {
  type    = number
  default = 40
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

variable "github_token" {
  type      = string
  sensitive = true
}

variable "branch" {
  type    = string
  default = "main"
}