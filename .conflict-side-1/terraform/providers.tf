terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc4"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.43.0"
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