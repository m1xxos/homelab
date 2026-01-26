module "main-cluster" {
  source = "./talos-cluster-module"
  talos_cps = [
    {
      name  = "main-cp-0"
      vm_id = 900
      ip    = "192.168.1.70"
    },
    {
      name  = "main-cp-1"
      vm_id = 901
      ip    = "192.168.1.71"
    },
    {
      name  = "main-cp-2"
      vm_id = 902
      ip    = "192.168.1.72"
    }
  ]
  talos_workers = [
    {
      name  = "main-worker-0"
      vm_id = 910
      ip    = "192.168.1.10"
    },
    {
      name  = "main-worker-1"
      vm_id = 911
      ip    = "192.168.1.11"
    },
    {
      name  = "main-worker-2"
      vm_id = 912
      ip    = "192.168.1.12"
    }
  ]
  worker_cpu_cores   = 6
  worker_memory      = 5120
  external_ip        = "192.168.1.80"
  cp_vip_address     = "192.168.1.75"
  talos_image_id     = proxmox_virtual_environment_download_file.talos_nocloud_image_1_11_3.id
  node_name          = "plusha"
  worker_disk_size   = 70
  cloudflare_zone_id = local.cloudflare_zone_id
  cluster_name       = "main"
  cluster_dns        = "main.k8s.m1xxos.tech"
  github_token       = local.github_token
  branch             = "380-authentik-gitlab-sso"
  cilium_version     = "1.18.4"
}