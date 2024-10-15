terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.60.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.43.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.5.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.16.0"
    }
  }
}

locals {
    kube_config = yamldecode(data.talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw)
}

provider "helm" {
  kubernetes {
    host = local.kube_config.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)

    client_certificate = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key = base64decode(local.kube_config.users[0].user.client-key-data)
  }
}