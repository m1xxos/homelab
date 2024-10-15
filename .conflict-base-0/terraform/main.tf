

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

module "test-cluster" {
  source = "./talos-cluster-module"
  talos_cps = [
    {
      name  = "test-cp"
      vm_id = 999
      ip    = "192.168.1.73"
    }
  ]
  talos_workers = [
    {
      name  = "test-worker"
      vm_id = 998
      ip    = "192.168.1.74"
    }
  ]
  cloudflare_zone_id = var.cloudflare_zone_id
  cluster_name       = "test-cluster"
  talos_image_id     = proxmox_virtual_environment_download_file.talos_nocloud_image.id
}