output "talosconfig" {
  value     = module.test-cluster.talosconfig
  sensitive = true
}

output "kubeconfig"{
    value = module.test-cluster.kubeconfig
    sensitive = true
}