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
  certificate_id          = 3
}

resource "nginxproxymanager_proxy_host" "k3s_proxy" {
  domain_names            = ["*.local.m1xxos.me"]
  forward_host            = "192.168.1.200"
  forward_port            = 443
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
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
  certificate_id          = 4
}