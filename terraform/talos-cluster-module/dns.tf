resource "cloudflare_record" "cluster-record" {
  zone_id = var.cloudflare_zone_id
  name    = "${var.cluster_name}.m1xxos.me"
  content = var.external_ip
  type    = "A"
  ttl     = 3600
}

resource "cloudflare_record" "cluster-record-extra" {
  zone_id = var.cloudflare_zone_id
  name    = "*.${var.cluster_name}"
  content = "${var.cluster_name}.m1xxos.me"
  type    = "CNAME"
  ttl     = 3600
}