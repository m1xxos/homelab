resource "proxmox_vm_qemu" "template_vm" {
  name        = var.name
  vmid        = var.vmid
  target_node = var.target_node
  desc        = var.desc
  qemu_os     = "l26"

  onboot = true

  clone = var.clone

  agent = 1

  cores   = var.cores
  sockets = 1
  memory  = var.memory

  scsihw = "virtio-scsi-pci"

  disks {
    virtio {
      virtio0 {
        disk {
          storage = var.storage
          size    = var.size
        }
      }
    }
  }

  os_type                 = "cloud-init"
  cloudinit_cdrom_storage = "local-lvm"

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }

  ipconfig0 = var.ipconfig0

}