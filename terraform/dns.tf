locals {
  local_name = "local.m1xxos.me"
}

resource "cloudflare_record" "main" {
  zone_id = var.cloudflare_zone_id
  name    = local.local_name
  value   = "192.168.1.200"
  type    = "A"
  ttl     = 3600
}

resource "cloudflare_record" "traefik" {
  zone_id = var.cloudflare_zone_id
  name    = "*.local"
  value   = local.local_name
  type    = "CNAME"
  ttl     = 3600
}
