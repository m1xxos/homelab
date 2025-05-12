locals {
  local_name = "local.m1xxos.tech"
}

resource "cloudflare_dns_record" "main" {
  zone_id = var.cloudflare_zone_id
  name    = local.local_name
  content = "192.168.1.250"
  type    = "A"
  ttl     = 300
}

resource "cloudflare_dns_record" "main-extra" {
  zone_id = var.cloudflare_zone_id
  name    = "*.local"
  content = local.local_name
  type    = "CNAME"
  ttl     = 300
}

resource "cloudflare_dns_record" "pi" {
  zone_id = var.cloudflare_zone_id
  name    = "pi.m1xxos.tech"
  content = "192.168.1.77"
  type    = "A"
  ttl     = 300
}

resource "cloudflare_dns_record" "pi-extra" {
  zone_id = var.cloudflare_zone_id
  name    = "*.pi"
  content = "pi.m1xxos.tech"
  type    = "CNAME"
  ttl     = 300
}
