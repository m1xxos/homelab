locals {
  node_name             = "plusha"
  cpu_type              = "host"
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
    cores = 1
    type  = local.cpu_type
  }

  memory {
    dedicated = 512
    floating  = 512
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = local.datastore_id
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_template.id
    file_format  = "raw"
    interface    = "scsi0"
    size         = 5
  }

  operating_system {
    type = local.operating_system_type
  }

  scsi_hardware = "virtio-scsi-single"
}