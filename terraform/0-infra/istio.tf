module "istio-cluster" {
  source = "./talos-cluster-module"
  talos_cps = [
    {
      name  = "istio-cp-0"
      vm_id = 800
      ip    = "192.168.1.71"
    }
  ]
  talos_workers = [
    {
      name  = "istio-worker-0"
      vm_id = 810
      ip    = "192.168.1.20"
    },
    {
      name  = "istio-worker-1"
      vm_id = 811
      ip    = "192.168.1.21"
    },
    {
      name  = "istio-worker-2"
      vm_id = 812
      ip    = "192.168.1.22"
    }
  ]
  worker_cpu_cores     = 6
  worker_memory        = 7168
  cp_memory            = 4096
  external_ip          = "192.168.1.86"
  cp_vip_address       = "192.168.1.76"
  talos_image_id       = proxmox_virtual_environment_download_file.talos_nocloud_template.id
  node_name            = "plusha"
  worker_disk_size     = 70
  cloudflare_zone_id   = local.cloudflare_zone_id
  cluster_name         = "istio"
  cluster_dns          = "istio.m1xxos.online"
  github_token         = local.github_token
  branch               = "istio-test"
  cilium_version       = "1.18.6"
  cluster_id           = 7
  clustermesh_endpoint = "192.168.1.85"
  create_cilium_ipv4_pool = true
}
