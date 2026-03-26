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


resource "cloudflare_dns_record" "home" {
  zone_id = "0f3617fcf7b220f1073d7536e1fb4aba"
  name    = "home.m1xxos.online"
  content = "192.168.1.128"
  type    = "A"
  ttl     = 300
}

resource "cloudflare_dns_record" "home-extra" {
  zone_id = "0f3617fcf7b220f1073d7536e1fb4aba"
  name    = "*.home.m1xxos.online"
  content = "home.m1xxos.online"
  type    = "CNAME"
  ttl     = 300
}

resource "cloudflare_dns_record" "gl" {
  zone_id = local.cloudflare_zone_id
  name    = "gl.${local.domain}"
  content = "192.168.1.80"
  type    = "A"
  ttl     = 300
}

resource "cloudflare_dns_record" "gl-extra" {
  zone_id = local.cloudflare_zone_id
  name    = "*.gl.${local.domain}"
  content = cloudflare_dns_record.gl.name
  type    = "CNAME"
  ttl     = 300
}
