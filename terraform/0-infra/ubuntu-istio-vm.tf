locals {
  ubuntu_istio = {
    hostname  = "istio-01"
    image_url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    file_name = "ubuntu-24.04-noble-cloudimg-amd64.img"
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_noble_cloudimg" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "plusha"

  file_name = local.ubuntu_istio.file_name
  url       = local.ubuntu_istio.image_url
  overwrite = false
}

resource "proxmox_virtual_environment_file" "ubuntu_istio_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "plusha"

  source_raw {
    file_name = "ubuntu-istio-01.yaml"
    data = <<-EOT
      #cloud-config
      hostname: ${local.ubuntu_istio.hostname}
      users:
        - name: m1xxos
          sudo: ALL=(ALL) NOPASSWD:ALL
          groups: [sudo]
          shell: /bin/bash
          ssh_authorized_keys:
            - ${file(pathexpand("~/.ssh/id_rsa.pub"))}
      package_update: true
      packages:
        - ca-certificates
        - curl
        - tar
      write_files:
        - path: /etc/istio/kubeconfig
          permissions: "0600"
          encoding: b64
          content: ${data.infisical_secrets.main.secrets["istio_workload_kubeconfig_b64"].value}
        - path: /usr/local/bin/istio-workload-setup.sh
          permissions: "0755"
          content: |
            #!/usr/bin/env bash
            set -euo pipefail
            ISTIO_VERSION="1.29.2"
            mkdir -p /etc/istio
            curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -
            install -m 0755 "istio-$ISTIO_VERSION/bin/istioctl" /usr/local/bin/istioctl
            /usr/local/bin/istioctl x workload entry configure \
              --kubeconfig /etc/istio/kubeconfig \
              --namespace vm \
              --workload-group ubutu \
              --service-account ubutu \
              --autoregister \
              --output /etc/istio
            systemctl daemon-reload
            systemctl enable --now istio-proxy
      runcmd:
        - ["/usr/local/bin/istio-workload-setup.sh"]
    EOT
  }
}

resource "proxmox_virtual_environment_vm" "ubuntu_istio" {
  name          = local.ubuntu_istio.hostname
  description   = "Managed by Terraform, ubuntu external workload"
  tags          = ["ubuntu", "istio", "workload"]
  node_name     = "plusha"
  vm_id         = 501
  on_boot       = true
  started       = true
  scsi_hardware = "virtio-scsi-single"

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = "pve-nvme"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_noble_cloudimg.id
    file_format  = "qcow2"
    interface    = "scsi0"
    size         = 30
    iothread     = true
    discard      = "on"
    cache        = "writeback"
  }

  serial_device {
    device = "socket"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id      = "pve-nvme"
    user_data_file_id = proxmox_virtual_environment_file.ubuntu_istio_cloud_init.id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }
}
