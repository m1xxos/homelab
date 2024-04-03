terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.28.0"
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

module "proxmox-k3s-agents" {
  source = "./proxmox-vm-module"

  count     = 3
  vmid      = 1300 + count.index
  cores     = 4
  memory    = 4096
  name      = "k3s-server-${count.index}"
  ipconfig0 = "ip=192.168.1.10${count.index}/24,gw=192.168.1.1"
  tags      = "k3s;server"

}

module "proxmox-k3s-server" {
  source = "./proxmox-vm-module"

  vmid      = 1303
  cores     = 4
  memory    = 4096
  name      = "k3s-agent"
  ipconfig0 = "ip=192.168.1.103/24,gw=192.168.1.1"
  tags      = "agent;k3s"

}

module "proxmox-lb" {
  source = "./proxmox-vm-module"
  for_each = tomap({
    1 = "master"
    2 = "backup"
  })


  vmid      = 1200 + each.key
  cores     = 2
  memory    = 2048
  name      = "lb-${each.key}"
  desc      = "lb-node"
  ipconfig0 = "ip=192.168.1.20${each.key}/24,gw=192.168.1.1"
  tags      = "lb;${each.value}"

}