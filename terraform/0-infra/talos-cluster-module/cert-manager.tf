resource "kubernetes_namespace_v1" "cert-manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "kubernetes_secret_v1" "name" {
  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = kubernetes_namespace_v1.cert-manager.metadata[0].name
  }
  data = {
    api-token = var.cloudflare_ip_token
  }
}