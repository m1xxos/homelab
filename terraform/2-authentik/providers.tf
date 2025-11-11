terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
      version = "2025.10.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.4.0"
    }
  }
  backend "s3" {
    endpoint                    = "https://storage.yandexcloud.net"
    region                      = "ru-central1"
    bucket                      = var.bucket
    key                         = "authentik-remote-state.tfstate"
    access_key                  = var.access_key
    secret_key                  = var.secret_key
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "authentik" {
  url = "https://authentik.local.m1xxos.tech/"
  token = ephemeral.vault_kv_secret_v2.authentik_token.data.token
}

provider "vault" {
  address = "https://vault.local.m1xxos.tech/"
  token   = var.vault_token
}
