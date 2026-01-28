terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.12.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.86.0"
    }
    infisical = {
      source  = "Infisical/infisical"
      version = "0.15.60"
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

provider "infisical" {
  host = "https://infisical.home.m1xxos.tech"
  auth = {
    universal = {
      client_id     = var.infisical_id
      client_secret = var.infisical_secret
    }
  }
}

provider "proxmox" {
  endpoint  = ephemeral.infisical_secret.proxmox_api_url.value
  username  = ephemeral.infisical_secret.proxmox_api_token_id.value
  api_token = ephemeral.infisical_secret.proxmox_api_token.value
  insecure  = true

  ssh {
    agent    = true
    username = "root"
    password = ephemeral.infisical_secret.proxmox_ssh_password.value
  }
}

provider "cloudflare" {
  api_token = ephemeral.infisical_secret.cloudflare_api_token.value
}
