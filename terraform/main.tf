module "main-cluster" {
  source = "./talos-cluster-module"
  talos_cps = [
    {
      name  = "main-cp-0"
      vm_id = 900
      ip    = "192.168.1.70"
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

  external_ip        = "192.168.1.80"
  node_name          = "plusha"
  worker_disk_size   = 40
  cloudflare_zone_id = var.cloudflare_zone_id
  cluster_name       = "main"
  cluster_dns        = "main.k8s.m1xxos.tech"
  talos_image_id     = proxmox_virtual_environment_download_file.talos_nocloud_image.id
  github_token       = var.github_token
  branch             = "v2.1"
}