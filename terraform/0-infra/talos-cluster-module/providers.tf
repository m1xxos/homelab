terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.97.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.17.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "= 3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "1.8.0"
    }
  }
}

locals {
  kube_config = yamldecode(talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw)
  kube_host   = "https://${var.cp_vip_address}:6443"
}

provider "helm" {
  kubernetes = {
    host = local.kube_host

    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
    client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
  }
}

provider "kubernetes" {
  host = local.kube_host

  cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
  client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
  client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
}

provider "flux" {
  kubernetes = {
    host = local.kube_host

    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
    client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
  }
  git = {
    url = var.git_url
    http = {
      username = "flux"
      password = var.github_token
    }
    branch = var.branch
  }
}