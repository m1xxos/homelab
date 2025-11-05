locals {
  node_name             = "plusha"
  cpu_type              = "x86-64-v2-AES"
  operating_system_type = "l26"
  datastore_id          = "pve-nvme"
}

resource "proxmox_virtual_environment_vm" "talos_template" {
  name        = "talos-template"
  description = "Managed by Terraform, talos"
  tags        = ["talos"]
  node_name   = local.node_name
  vm_id       = 110
  on_boot     = true
  template    = true


  cpu {
    cores = 4
    type  = local.cpu_type
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
    datastore_id = local.datastore_id
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image.id
    file_format  = "raw"
    interface    = "virtio0"
    size         = 40
  }

  operating_system {
    type = local.operating_system_type
  }
}