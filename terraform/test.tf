resource "proxmox_vm_qemu" "resource-name" {
  name        = "VM-name"
  target_node = "pve"
  iso         = "local:iso/ubuntu-22.04.4-live-server-amd64.iso"

}