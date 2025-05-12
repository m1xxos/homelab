terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.3.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.77.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.8.0"
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
  endpoint  = var.proxmox_api_url
  username  = var.proxmox_api_token_id
  api_token = var.proxmox_talos_api_token
  insecure  = true

  ssh {
    agent    = true
    username = "root"
    password = var.ssh_password
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
