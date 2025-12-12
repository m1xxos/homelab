locals {
  talos = {
    version = "v1.8.0"
  }
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "plusha"

  file_name               = "talos-${local.talos.version}-nocloud-amd64-iscsi.img"
  url                     = "https://factory.talos.dev/image/f2716897efdcc84fb9cef8d04b20631b2ba11de56a941eee5a6577e4a5c08dc7/${local.talos.version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image_1_11_3" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "plusha"

  file_name               = "talos-v1.11.3-nocloud-amd64-iscsi.img"
  url                     = "https://factory.talos.dev/image/f2716897efdcc84fb9cef8d04b20631b2ba11de56a941eee5a6577e4a5c08dc7/v1.11.3/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_template" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "plusha"

  file_name               = "talos-v1.11.5-nocloud-amd64-template.img"
  url                     = "https://factory.talos.dev/image/974c44bde6b7a95c8fe9038ae3625138c37d8b9d91940fa90ef05ffaacabc8a0/v1.11.5/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}
