# locals {
#   talos_cp_ips = [
#     for ip in var.var.talos_cps.ip
#   ]
#   talos_worker_ips = [
#     var.talos_worker_01_ip_addr,
#     var.talos_worker_02_ip_addr,
#     var.talos_worker_03_ip_addr
#   ]
# }

# resource "talos_machine_secrets" "machine_secrets" {}

# data "talos_client_configuration" "talosconfig" {
#   cluster_name         = var.cluster_name
#   client_configuration = talos_machine_secrets.machine_secrets.client_configuration
#   endpoints            = [var.talos_cp_01_ip_addr, var.talos_cp_02_ip_addr, var.talos_cp_03_ip_addr]
# }

# data "talos_machine_configuration" "machineconfig_cp" {
#   cluster_name     = var.cluster_name
#   cluster_endpoint = "https://${var.talos_cp_01_ip_addr}:6443"
#   machine_type     = "controlplane"
#   machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
# }

# resource "talos_machine_configuration_apply" "cp_config_apply" {
#   depends_on                  = [proxmox_virtual_environment_vm.talos_cp_01]
#   client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
#   machine_configuration_input = data.talos_machine_configuration.machineconfig_cp.machine_configuration
#   count                       = 3
#   node                        = local.talos_cp_ips[count.index]
#   config_patches = [
#     yamlencode({
#       cluster = {
#         network = {
#           cni = {
#             name = "none"
#           }
#         }
#       },
#       machine = {
#         kubelet = {
#           extraMounts = [
#             {destination = "/var/lib/longhorn",
#             type = "bind",
#             source = "/var/lib/longhorn",
#             options = [
#               "bind", "rshared", "rw"
#             ]}
#           ]
#         }
#       }
#     })
#   ]
# }

# data "talos_machine_configuration" "machineconfig_worker" {
#   cluster_name     = var.cluster_name
#   cluster_endpoint = "https://${var.talos_cp_01_ip_addr}:6443"
#   machine_type     = "worker"
#   machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
# }

# resource "talos_machine_configuration_apply" "worker_config_apply" {
#   depends_on                  = [proxmox_virtual_environment_vm.talos_worker_01, proxmox_virtual_environment_vm.talos_worker_02, proxmox_virtual_environment_vm.talos_worker_03]
#   client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
#   machine_configuration_input = data.talos_machine_configuration.machineconfig_worker.machine_configuration
#   count                       = 3
#   node                        = local.talos_worker_ips[count.index]
#   config_patches = [
#     yamlencode({
#       cluster = {
#         network = {
#           cni = {
#             name = "none"
#           }
#         }
#         clusterName = var.cluster_name
#       },
#       machine = {
#         kubelet = {
#           extraMounts = [
#             {destination = "/var/lib/longhorn",
#             type = "bind",
#             source = "/var/lib/longhorn",
#             options = [
#               "bind", "rshared", "rw"
#             ]}
#           ]
#         }
#       }
#     })
#   ]
# }

# resource "talos_machine_bootstrap" "bootstrap" {
#   depends_on           = [talos_machine_configuration_apply.cp_config_apply]
#   client_configuration = talos_machine_secrets.machine_secrets.client_configuration
#   node                 = var.talos_cp_01_ip_addr
# }

# data "talos_cluster_health" "health" {
#   depends_on           = [talos_machine_configuration_apply.cp_config_apply, talos_machine_configuration_apply.worker_config_apply]
#   client_configuration = data.talos_client_configuration.talosconfig.client_configuration
#   control_plane_nodes  = [var.talos_cp_01_ip_addr, var.talos_cp_02_ip_addr, var.talos_cp_03_ip_addr]
#   worker_nodes         = [var.talos_worker_01_ip_addr, var.talos_worker_02_ip_addr, var.talos_worker_03_ip_addr]
#   endpoints            = data.talos_client_configuration.talosconfig.endpoints
# }

# data "talos_cluster_kubeconfig" "kubeconfig" {
#   depends_on           = [talos_machine_bootstrap.bootstrap, data.talos_cluster_health.health]
#   client_configuration = talos_machine_secrets.machine_secrets.client_configuration
#   node                 = var.talos_cp_01_ip_addr
# }
