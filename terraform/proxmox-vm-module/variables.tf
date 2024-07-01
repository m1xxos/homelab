variable "name" {
  type    = string
  default = "terraform-k3s-vm"
}

variable "vmid" {
  type = number
}

variable "target_node" {
  type    = string
  default = "pve"
}

variable "desc" {
  type    = string
  default = "k3s node"
}

variable "clone" {
  type    = string
  default = "ubuntu-server-mantic"
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

variable "storage" {
  type    = string
  default = "pve-nvme"
}

variable "size" {
  type    = number
  default = 20
}

variable "ipconfig0" {
  type    = string
  default = "ip=dhcp"
}

variable "tags" {
  type = string
  default = "null"
}

variable "onboot" {
  type = bool
  default = true
}

variable "vm_state" {
  type = string
  default = "running"
}

variable "vlan" {
  type = bool
  default = false
}
