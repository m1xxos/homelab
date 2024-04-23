terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.28.0"
    }
    nginxproxymanager = {
      source  = "Sander0542/nginxproxymanager"
      version = "0.0.33"
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

module "proxmox-k3s-agents" {
  source = "./proxmox-vm-module"

  count     = 3
  vmid      = 1300 + count.index
  cores     = 4
  memory    = 4096
  name      = "k3s-server-${count.index}"
  ipconfig0 = "ip=192.168.1.10${count.index}/24,gw=192.168.1.1"
  tags      = "k3s;server"
  clone     = "ubuntu-server-lunar"
}

module "proxmox-k3s-server" {
  source = "./proxmox-vm-module"

  vmid      = 1303
  cores     = 4
  memory    = 4096
  name      = "k3s-agent"
  ipconfig0 = "ip=192.168.1.103/24,gw=192.168.1.1"
  tags      = "agent;k3s"
  clone     = "ubuntu-server-lunar"

}

module "proxmox-lb" {
  source = "./proxmox-vm-module"
  for_each = tomap({
    1 = "lb;master"
    2 = "backup;lb"
  })


  vmid      = 1200 + each.key
  cores     = 2
  memory    = 2048
  name      = "lb-${each.key - 1}"
  desc      = "lb-node"
  ipconfig0 = "ip=192.168.1.20${each.key}/24,gw=192.168.1.1"
  tags      = each.value
}

module "proxmox-nginx-proxy" {
  source = "./proxmox-vm-module"

  vmid      = 1100
  cores     = 4
  memory    = 4096
  name      = "nginx-proxy-0"
  desc      = "proxy"
  ipconfig0 = "ip=192.168.1.250/24,gw=192.168.1.1"
  tags      = "nginx"
  size      = 60

}

resource "proxmox_vm_qemu" "proxmox-truenas" {
  vmid   = 1500
  cores  = 4
  memory = 8192
  name   = "truenas-0"
  desc   = "TrueNAS vm"
  iso    = "local:iso/TrueNAS-SCALE-23.10.2.iso"

  tags        = "truenas"
  onboot      = false
  target_node = "pve"
  qemu_os     = "l26"
  agent       = 0

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }

  scsihw = "virtio-scsi-pci"
  disks {
    virtio {
      virtio0 {
        disk {
          storage = "pve-nvme"
          size    = 20
        }
      }
      virtio1 {
        disk {
          storage = "pve-nvme"
          size    = 60
        }
      }
    }
  }
}

