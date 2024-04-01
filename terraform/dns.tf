resource "cloudflare_record" "main" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  value   = "192.168.1.103"
  type    = "A"
  ttl     = 3600
}

resource "cloudflare_record" "traefik" {
  zone_id = var.cloudflare_zone_id
  name    = "traefik"
  value   = "@"
  type    = "CNAME"
  ttl     = 3600
}

resource "cloudflare_record" "frog" {
  zone_id = var.cloudflare_zone_id
  name    = "frog"
  value   = "@"
  type    = "CNAME"
  ttl     = 3600
}
