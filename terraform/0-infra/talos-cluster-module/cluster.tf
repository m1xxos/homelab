locals {
  talos_cp_ips = [
    for vm in var.talos_cps : vm.ip
  ]
  talos_worker_ips = [
    for vm in var.talos_workers : vm.ip
  ]
  config_patches = yamlencode({
    cluster = {
      network = {
        cni = {
          name = "none"
        }
      },
    },
    machine = {
      kubelet = {
        extraMounts = [
          { destination = "/var/lib/longhorn",
            type        = "bind",
            source      = "/var/lib/longhorn",
            options = [
              "bind", "rshared", "rw"
          ] }
        ]
      }
    }
  })
  control_plane_patches = yamlencode({
    cluster = {
      controllerManager = {
        extraArgs = {
          bind-address = "0.0.0.0"
        }
      },
      scheduler = {
        extraArgs = {
          bind-address = "0.0.0.0",
        }
      }
    }
    machine = {
      network = {
        interfaces = [
          {
            deviceSelector = {
              physical = true
            }
            vip = {
              ip = var.vip_addres
            }
          }
        ]
      }
    }
  })
}

resource "talos_machine_secrets" "machine_secrets" {}

data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = local.talos_cp_ips
}

data "talos_machine_configuration" "machineconfig_cp" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.talos_cp_ips[0]}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
}

resource "talos_machine_configuration_apply" "cp_config_apply" {
  for_each                    = toset(local.talos_cp_ips)
  depends_on                  = [proxmox_virtual_environment_vm.talos_cp]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_cp.machine_configuration
  node                        = each.key
  config_patches              = [local.config_patches, local.control_plane_patches]
  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.talos_cp]
  }
}

data "talos_machine_configuration" "machineconfig_worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.talos_cp_ips[0]}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
}

resource "talos_machine_configuration_apply" "worker_config_apply" {
  for_each                    = toset(local.talos_worker_ips)
  depends_on                  = [proxmox_virtual_environment_vm.talos_worker]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_worker.machine_configuration
  node                        = each.key
  config_patches              = [local.config_patches]
  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.talos_worker]
  }
}

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on           = [talos_machine_configuration_apply.cp_config_apply]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = local.talos_cp_ips[0]
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = local.talos_cp_ips[0]
  endpoint             = var.vip_addres
}
