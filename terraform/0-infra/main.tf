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
  worker_cpu_cores     = 6
  worker_memory        = 6144
  cp_memory            = 6144
  external_ip          = "192.168.1.80"
  cp_vip_address       = "192.168.1.75"
  talos_image_id       = proxmox_virtual_environment_download_file.talos_nocloud_image_1_11_3.id
  node_name            = "plusha"
  worker_disk_size     = 70
  cloudflare_zone_id   = local.cloudflare_zone_id
  cluster_name         = "main"
  cluster_dns          = "main.k8s.m1xxos.tech"
  github_token         = local.github_token
  branch               = "388-s3-operator"
  cilium_version       = "1.18.6"
  clustermesh_endpoint = "192.168.1.81"
}