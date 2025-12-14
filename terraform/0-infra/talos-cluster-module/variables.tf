
variable "cluster_name" {
  type    = string
  default = "homelab"
}

variable "cluster_dns" {
  type    = string
  default = "homelab.m1xxos.tech"
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

variable "cloudflare_zone_id" {
  type      = string
  sensitive = true
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "git_url" {
  type    = string
  default = "https://github.com/m1xxos/homelab.git"
}

variable "branch" {
  type    = string
  default = "main"
}

variable "cilium_version" {
  type    = string
  default = "1.17.3"
}

variable "metrics_server_version" {
  type    = string
  default = "3.12.2"
}

variable "node_name" {
  type = string
}

variable "cp_vip_address" {
  type = string
}

variable "talos_image_id" {
  type = string
}
