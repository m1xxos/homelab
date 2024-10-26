terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc4"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.44.0"
    }
    nginxproxymanager = {
      source  = "Sander0542/nginxproxymanager"
      version = "0.0.33"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = "2024.8.4"
    }
  }
  backend "s3" {
    endpoint                    = "https://storage.yandexcloud.net"
    region                      = "ru-central1"
    bucket                      = var.bucket
    key                         = "terraform-remote-state.tfstate"
    access_key                  = var.access_key
    secret_key                  = var.secret_key
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret

}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "authentik" {
  url   = "https://auth.home.m1xxos.me"
  token = var.authentik_token
}

module "proxmox-k3s-agents" {
  source = "./proxmox-vm-module"
  onboot = false
  vm_state = "stopped"

  count     = 1
  vmid      = 1301 + count.index
  cores     = 4
  memory    = 4096
  name      = "k3s-agent-${count.index}"
  ipconfig0 = "ip=192.168.1.10${count.index + 1}/24,gw=192.168.1.1"
  tags      = "agent;k3s"
}

module "proxmox-k3s-server" {
  source = "./proxmox-vm-module"
  onboot = false
  vm_state = "stopped"

  vmid      = 1300
  cores     = 4
  memory    = 4096
  name      = "k3s-server-0"
  ipconfig0 = "ip=192.168.1.100/24,gw=192.168.1.1"
  tags      = "k3s;server"
}

module "proxmox-lb" {
  source = "./proxmox-vm-module"

  onboot   = false
  vm_state = "stopped"

  for_each = tomap({
    1 = "lb;master"
    2 = "backup;lb"
  })


  vmid      = 1200 + each.key
  cores     = 2
  memory    = 2048
  name      = "lb-${each.key - 1}"
  desc      = "lb-node"
  ipconfig0 = "ip=192.168.1.20${each.key}/24,gw=192.168.1.1"
  tags      = each.value
}


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
      name  = "test-cp-0"
      vm_id = 900
      ip    = "192.168.1.70"
    },
    {
      name  = "test-cp-1"
      vm_id = 901
      ip    = "192.168.1.71"
    }
  ]
  talos_workers = [
    {
      name  = "test-worker-0"
      vm_id = 902
      ip    = "192.168.1.72"
    },
    {
      name  = "test-worker-1"
      vm_id = 903
      ip    = "192.168.1.73"
    },
    {
      name  = "test-worker-2"
      vm_id = 904
      ip    = "192.168.1.74"
    }
  ]

  external_ip        = "192.168.1.80"
  worker_disk_size   = 40
  cloudflare_zone_id = var.cloudflare_zone_id
  cluster_name       = "test-cluster"
  talos_image_id     = proxmox_virtual_environment_download_file.talos_nocloud_image.id
  github_token       = var.github_token
  branch             = "main"
}