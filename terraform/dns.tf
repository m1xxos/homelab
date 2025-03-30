locals {
  local_name = "local.m1xxos.tech"
}

resource "cloudflare_record" "main" {
  zone_id = var.cloudflare_zone_id
  name    = local.local_name
  content = "192.168.1.250"
  type    = "A"
  ttl     = 300
}

resource "cloudflare_record" "traefik" {
  zone_id = var.cloudflare_zone_id
  name    = "*.local"
  content = local.local_name
  type    = "CNAME"
  ttl     = 300
}

resource "cloudflare_record" "home" {
  zone_id = var.cloudflare_zone_id
  name    = "home"
  content = "192.168.1.250"
  type    = "A"
  ttl     = 300
}

resource "cloudflare_record" "home-extra" {
  zone_id = var.cloudflare_zone_id
  name    = "*.home"
  content = "home.m1xxos.tech"
  type    = "CNAME"
  ttl     = 300
}

resource "cloudflare_record" "minikube" {
  zone_id = var.cloudflare_zone_id
  name    = "minikube.m1xxos.tech"
  content = "127.0.0.1"
  type    = "A"
  ttl     = 300
}

resource "cloudflare_record" "minikube-extra" {
  zone_id = var.cloudflare_zone_id
  name    = "*.minikube"
  content = "minikube.m1xxos.tech"
  type    = "CNAME"
  ttl     = 300
}

resource "cloudflare_record" "pi" {
  zone_id = var.cloudflare_zone_id
  name    = "pi.m1xxos.tech"
  content = "192.168.1.77"
  type    = "A"
  ttl     = 300
}

resource "cloudflare_record" "pi-extra" {
  zone_id = var.cloudflare_zone_id
  name    = "*.pi"
  content = "pi.m1xxos.tech"
  type    = "CNAME"
  ttl     = 300
}
