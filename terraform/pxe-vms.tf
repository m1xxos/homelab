resource "proxmox_vm_qemu" "maas_vms" {
name                      = "pxe-minimal-example"
agent                     = 0
boot                      = "order=scsi0;net0"
pxe                       = true
target_node               = "pve"
network {
    bridge    = "vmbr0"
    firewall  = false
    link_down = false
    model     = "e1000"
}
#   count = 3

#   name        = "maas-${count.index}"
#   vmid        = 1130 + count.index
#   target_node = "pve"
#   desc        = "maas vm"
#   qemu_os     = "l26"
  

#   onboot = false

#   pxe   = true
#   boot  = "scsi0;net0"
#   agent = 0

#   cores   = 4
#   sockets = 1
#   memory  = 4096

#   network {
#     bridge    = "vmbr0"
#     firewall  = false
#     link_down = false
#     model     = "e1000"
#   }


#   tags = "maas"

}