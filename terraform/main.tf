

module "proxmox-portainer" {
  source = "./proxmox-vm-module"

  onboot   = false
  vm_state = "stopped"

  vmid      = 1150
  cores     = 6
  memory    = 10240
  name      = "portainer-0"
  desc      = "portainer/gitlab"
  ipconfig0 = "ip=192.168.1.228/24,gw=192.168.1.1"
  tags      = "portainer"
  size      = 60

}

module "proxmox-home" {
  source = "./proxmox-vm-module"

  vmid      = 1090
  cores     = 6
  memory    = 8192
  name      = "home-0"
  desc      = "home servers"
  ipconfig0 = "ip=192.168.1.99/24,gw=192.168.1.1"
  tags      = "home"
  size      = 60
}

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
      ip    = "192.168.1.75"
    },
    {
      name  = "main-worker-1"
      vm_id = 911
      ip    = "192.168.1.76"
    },
    {
      name  = "main-worker-2"
      vm_id = 912
      ip    = "192.168.1.77"
    }
  ]
  worker_disk_size   = 40
  cloudflare_zone_id = var.cloudflare_zone_id
  cluster_name       = "main"
  talos_image_id     = proxmox_virtual_environment_download_file.talos_nocloud_image.id
  github_token       = var.github_token
  branch             = "167-big-rebuild"
}