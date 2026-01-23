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
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
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

ephemeral "infisical_secret" "proxmox_api_url" {
    name = "proxmox_api_url"
    env_slug = "prod"
    folder_path = "/"
    workspace_id = var.infisical_workspace_id
}

ephemeral "infisical_secret" "proxmox_api_token_id" {
    name = "proxmox_api_token_id"
    env_slug = "prod"
    folder_path = "/"
    workspace_id = var.infisical_workspace_id
}

ephemeral "infisical_secret" "proxmox_api_token" {
    name = "proxmox_api_token"
    env_slug = "prod"
    folder_path = "/"
    workspace_id = var.infisical_workspace_id
}

locals {
  proxmox_api_url = ephemeral.infisical_secret.proxmox_api_url.value
  proxmox_api_token_id = ephemeral.infisical_secret.proxmox_api_token_id.value
  proxmox_api_token = ephemeral.infisical_secret.proxmox_api_token.value
}

provider "proxmox" {
  endpoint  = local.proxmox_api_url
  username  = local.proxmox_api_token_id
  api_token = local.proxmox_api_token
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

