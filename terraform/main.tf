terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc1"
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

module "proxmox-k3s-agents" {
  source = "./proxmox-vm-module"

  count     = 3
  vmid      = 1300 + count.index
  cores     = 4
  memory    = 4096
  name      = "k3s-node-${count.index}"
  ipconfig0 = "ip=192.168.1.10${count.index}/24,gw=192.168.1.1"
  tags      = "k3s, agent"

}

module "proxmox-k3s-server" {
  source = "./proxmox-vm-module"

  vmid      = 1303
  cores     = 4
  memory    = 4096
  name      = "k3s-server"
  ipconfig0 = "ip=192.168.1.103/24,gw=192.168.1.1"
  tags      = "k3s, server"

}