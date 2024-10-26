locals {
  node_name             = "pve"
  cpu_type              = "x86-64-v2-AES"
  operating_system_type = "l26"
  datastore_id          = "pve-nvme"
}

resource "proxmox_virtual_environment_vm" "talos_cp" {
  for_each = {
    for cp in var.talos_cps :
    cp.name => cp
  }
  name        = each.value.name
  description = "Managed by Terraform, talos"
  tags        = ["talos", var.cluster_name]
  node_name   = local.node_name
  vm_id       = each.value.vm_id
  on_boot     = true


  cpu {
    cores = var.cp_cpu_cores
    type  = local.cpu_type
  }

  memory {
    dedicated = var.cp_memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = local.datastore_id
    file_id      = var.talos_image_id
    file_format  = "raw"
    interface    = "virtio0"
    size         = var.cp_disk_size
  }

  operating_system {
    type = local.operating_system_type
  }

  initialization {
    datastore_id = local.datastore_id
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
  node_name   = local.node_name
  vm_id       = each.value.vm_id
  on_boot     = true


  cpu {
    cores = var.worker_cpu_cores
    type  = local.cpu_type
  }

  memory {
    dedicated = var.worker_memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = local.datastore_id
    file_id      = var.talos_image_id
    file_format  = "raw"
    interface    = "virtio0"
    size         = var.worker_disk_size
  }

  operating_system {
    type = local.operating_system_type # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    datastore_id = local.datastore_id
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
