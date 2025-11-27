module "main-cluster" {
  source = "./talos-cluster-module"
  talos_cps = [
    {
      name           = "main-cp-0"
      vm_id          = 900
      ip             = "192.168.1.70"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_image_1_11_3.id
    },
    {
      name           = "main-cp-1"
      vm_id          = 901
      ip             = "192.168.1.71"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_image_1_11_3.id
    },
    {
      name           = "main-cp-2"
      vm_id          = 902
      ip             = "192.168.1.72"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_image_1_11_3.id
    }
  ]
  talos_workers = [
    {
      name           = "main-worker-0"
      vm_id          = 910
      ip             = "192.168.1.10"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_image_1_11_3.id
    },
    {
      name           = "main-worker-1"
      vm_id          = 911
      ip             = "192.168.1.11"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_image_1_11_3.id
    },
    {
      name           = "main-worker-2"
      vm_id          = 912
      ip             = "192.168.1.12"
      talos_image_id = proxmox_virtual_environment_download_file.talos_nocloud_image_1_11_3.id
    }
  ]
  worker_cpu_cores   = 6
  worker_memory      = 6144
  external_ip        = "192.168.1.80"
  node_name          = "plusha"
  worker_disk_size   = 70
  cloudflare_zone_id = var.cloudflare_zone_id
  cluster_name       = "main"
  cluster_dns        = "main.k8s.m1xxos.tech"
  github_token       = var.github_token
  branch             = "352-cluster-api-proxmox-talos-iso"
  cilium_version     = "1.18.0"
}