resource "proxmox_vm_qemu" "template_vm" {
  name        = var.name
  vmid        = var.vmid
  target_node = var.target_node
  desc        = var.desc
  qemu_os     = "l26"

  onboot = var.onboot

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
    ide {
      ide2 {
        cdrom {
          passthrough = false
        }
      }
      ide3 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  os_type = "cloud-init"

  network {
    bridge = "vmbr0"
    model  = "virtio"
    id = 0
  }

  ipconfig0 = var.ipconfig0

  tags = var.tags

  vm_state = var.vm_state

}