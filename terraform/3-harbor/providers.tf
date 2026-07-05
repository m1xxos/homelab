terraform {
  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "3.12.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.10.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
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

provider "harbor" {
  url      = var.harbor_url
  username = "admin"
  password = data.vault_kv_secret_v2.harbor_admin.data["password"]
  insecure = false
}

provider "vault" {
  address = var.vault_address
}
