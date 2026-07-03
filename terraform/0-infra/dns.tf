locals {
  domain = "m1xxos.online"
}

resource "cloudflare_dns_record" "main" {
  zone_id = local.cloudflare_zone_id
  name    = "local.${local.domain}"
  content = "192.168.1.80"
  type    = "A"
  ttl     = 300
}

resource "cloudflare_dns_record" "main-extra" {
  zone_id = local.cloudflare_zone_id
  name    = "*.local.${local.domain}"
  content = cloudflare_dns_record.main.name
  type    = "CNAME"
  ttl     = 300
}
