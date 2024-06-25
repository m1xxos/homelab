resource "proxmox_vm_qemu" "maas_vms" {
  count = 3

  name        = "maas-${count.index}"
  desc        = "maas vm"
  tags        = "maas"
  vmid        = 1130 + count.index
  target_node = "pve"
  agent       = 0
  boot        = "order=net0"
  pxe         = true

  cores   = 4
  sockets = 1
  memory  = 4096

  network {
    bridge    = "vmbr0"
    firewall  = false
    link_down = false
    model     = "e1000"
  }

  vm_state = "stopped"
}