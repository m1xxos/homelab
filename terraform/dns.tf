locals {
  local_name = "local.m1xxos.me"
}

resource "cloudflare_record" "main" {
  zone_id = var.cloudflare_zone_id
  name    = local.local_name
  content = "192.168.1.250"
  type    = "A"
  ttl     = 3600
}

resource "cloudflare_record" "traefik" {
  zone_id = var.cloudflare_zone_id
  name    = "*.local"
  content = local.local_name
  type    = "CNAME"
  ttl     = 3600
}

resource "cloudflare_record" "home" {
  zone_id = var.cloudflare_zone_id
  name    = "home"
  content = "192.168.1.250"
  type    = "A"
  ttl     = 3600
}

resource "cloudflare_record" "home-extra" {
  zone_id = var.cloudflare_zone_id
  name    = "*.home"
  content = "home.m1xxos.me"
  type    = "CNAME"
  ttl     = 3600
}

resource "cloudflare_record" "minikube" {
  zone_id = var.cloudflare_zone_id
  name    = "minikube.m1xxos.me"
  content = "127.0.0.1"
  type    = "A"
  ttl     = 3600
}

resource "cloudflare_record" "minikube-extra" {
  zone_id = var.cloudflare_zone_id
  name    = "*.minikube"
  content = "minikube.m1xxos.me"
  type    = "CNAME"
  ttl     = 3600
}

resource "cloudflare_record" "omnivore" {
  zone_id = var.cloudflare_zone_id
  name    = "minikube.m1xxos.me"
  content = "192.168.1.211"
  type    = "A"
  ttl     = 3600
}