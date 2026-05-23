terraform {
  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "3.11.6"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
  }
  backend "s3" {
    endpoint                    = "https://storage.yandexcloud.net"
    region                      = "ru-central1"
    bucket                      = var.bucket
    key                         = "harbor-remote-state.tfstate"
    access_key                  = var.access_key
    secret_key                  = var.secret_key
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

data "vault_kv_secret_v2" "harbor_admin" {
  mount = "main"
  name  = "harbor/admin"
}

data "vault_kv_secret_v2" "harbor_gcr" {
  mount = "main"
  name  = "harbor/gcr"
}

provider "harbor" {
  url      = "https://harbor.local.m1xxos.online"
  username = "admin"
  password = data.vault_kv_secret_v2.harbor_admin.data["password"]
  insecure = false
}

provider "vault" {
  address = var.vault_address
}
