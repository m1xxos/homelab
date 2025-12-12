module "pulsar-cluster" {
  source = "./talos-cluster-module"
  talos_cps = [
    {
      name           = "pulsar-cp-0"
      vm_id          = 800
      ip             = "192.168.1.74"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_template.id
    },
    {
      name           = "pulsar-cp-1"
      vm_id          = 801
      ip             = "192.168.1.75"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_template.id
    },
    {
      name           = "pulsar-cp-2"
      vm_id          = 802
      ip             = "192.168.1.76"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_template.id
    }
  ]
  talos_workers = [
    {
      name           = "pulsar-worker-0"
      vm_id          = 810
      ip             = "192.168.1.30"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_template.id
    },
    {
      name           = "pulsar-worker-1"
      vm_id          = 811
      ip             = "192.168.1.31"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_template.id
    },
    {
      name           = "pulsar-worker-2"
      vm_id          = 812
      ip             = "192.168.1.32"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_template.id
    },
    {
      name           = "pulsar-worker-3"
      vm_id          = 813
      ip             = "192.168.1.33"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_template.id
    }
  ]
  worker_cpu_cores   = 12
  worker_memory      = 12228
  external_ip        = "192.168.1.85"
  vip_address        = "192.168.1.45"
  node_name          = "plusha"
  worker_disk_size   = 70
  cloudflare_zone_id = var.cloudflare_zone_id
  cluster_name       = "pulsar"
  cluster_dns        = "pulsar.k8s.m1xxos.tech"
  github_token       = var.github_token
  branch             = "pulsar-test"
  cilium_version     = "1.18.0"
}