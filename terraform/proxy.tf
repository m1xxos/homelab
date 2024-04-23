provider "nginxproxymanager" {
  host     = "http://192.168.1.250:81"
  username = var.nginx_username
  password = var.nginx_password
}


resource "nginxproxymanager_proxy_host" "proxmox_proxy" {
  domain_names            = ["proxmox.local.m1xxos.me"]
  forward_host            = "192.168.1.122"
  forward_port            = 8006
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
  http2_support           = true
  hsts_enabled            = true
  certificate_id          = 5
}

resource "nginxproxymanager_proxy_host" "k3s_proxy" {
  domain_names            = ["*.local.m1xxos.me"]
  forward_host            = "192.168.1.200"
  forward_port            = 443
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
  http2_support           = true
  hsts_enabled            = true
  certificate_id          = 3
}

resource "nginxproxymanager_proxy_host" "tunnel_proxmox_proxy" {
  domain_names            = ["proxmox.m1xxos.me"]
  forward_host            = "192.168.1.122"
  forward_port            = 8006
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
  http2_support           = true
  hsts_enabled            = true
  certificate_id          = 6
}

resource "nginxproxymanager_proxy_host" "tunnel_sonar_proxy" {
  domain_names            = ["sonar.m1xxos.me"]
  forward_host            = "192.168.1.200"
  forward_port            = 443
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
  http2_support           = true
  hsts_enabled            = true
  certificate_id          = 7
}

resource "nginxproxymanager_proxy_host" "nas_proxy" {
  domain_names            = ["nas.local.m1xxos.me"]
  forward_host            = "192.168.1.143"
  forward_port            = 443
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
  http2_support           = true
  hsts_enabled            = true
  certificate_id          = 3
}
