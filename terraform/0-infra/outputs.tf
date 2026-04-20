output "talosconfig" {
  value     = module.main-cluster.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.main-cluster.kubeconfig
  sensitive = true
}

output "kubeconfig_istion" {
  value     = module.istio-cluster.kubeconfig
  sensitive = true
}
