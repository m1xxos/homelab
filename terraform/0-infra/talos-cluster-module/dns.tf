locals {
  ttl = 300
}

resource "cloudflare_dns_record" "cluster-record" {
  zone_id = var.cloudflare_zone_id
  name    = var.cluster_dns
  content = var.external_ip
  type    = "A"
  ttl     = local.ttl
}

resource "cloudflare_dns_record" "cluster-record-extra" {
  zone_id = var.cloudflare_zone_id
  name    = "*.${var.cluster_dns}"
  content = var.cluster_name
  type    = "CNAME"
  ttl     = local.ttl
}
