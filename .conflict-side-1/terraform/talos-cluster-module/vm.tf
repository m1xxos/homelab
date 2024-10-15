resource "proxmox_virtual_environment_vm" "talos_cp" {
  for_each = {
    for cp in var.talos_cps :
    cp.name => cp
  }
  name        = each.value.name
  description = "Managed by Terraform, talos"
  tags        = ["talos", var.cluster_name]
  node_name   = "pve"
  vm_id       = each.value.vm_id
  on_boot     = true


  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = "pve-nvme"
    file_id      = var.talos_image_id
    file_format  = "raw"
    interface    = "virtio0"
    size         = 20
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    datastore_id = "pve-nvme"
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.default_gateway
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }
}

resource "proxmox_virtual_environment_vm" "talos_worker" {
  for_each = {
    for worker in var.talos_workers :
    worker.name => worker
  }
  depends_on  = [proxmox_virtual_environment_vm.talos_cp]
  name        = each.value.name
  description = "Managed by Terraform"
  tags        = ["talos", var.cluster_name]
  node_name   = "pve"
  vm_id       = each.value.vm_id
  on_boot     = true


  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = "pve-nvme"
    file_id      = var.talos_image_id
    file_format  = "raw"
    interface    = "virtio0"
    size         = 20
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    datastore_id = "pve-nvme"
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.default_gateway
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }
}
