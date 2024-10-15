resource "proxmox_vm_qemu" "proxy-vm" {
  name        = "nginx-proxy-0"
  vmid        = 1100
  target_node = "pve"
  desc        = "proxy"
  qemu_os     = "l26"

  onboot = true

  clone = "ubuntu-server-mantic"

  agent = 1

  cores   = 4
  sockets = 1
  memory  = 6144

  scsihw = "virtio-scsi-pci"

  disks {
    virtio {
      virtio0 {
        disk {
          storage = "pve-nvme"
          size    = 60
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
  }

  ipconfig0 = "ip=192.168.1.250/24,gw=192.168.1.1"

  tags = "nginx"

}
