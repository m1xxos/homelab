output "talosconfig" {
  value     = module.main-cluster.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.main-cluster.kubeconfig
  sensitive = true
}
