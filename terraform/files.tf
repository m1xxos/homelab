locals {
  talos = {
    version = "v1.8.0"
  }
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"

  file_name               = "talos-${local.talos.version}-nocloud-amd64-iscsi.img"
  url                     = "https://factory.talos.dev/image/f2716897efdcc84fb9cef8d04b20631b2ba11de56a941eee5a6577e4a5c08dc7/${local.talos.version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}