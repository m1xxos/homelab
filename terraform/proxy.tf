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
  certificate_id          = 1
}

resource "nginxproxymanager_proxy_host" "k3s_proxy" {
  domain_names            = ["*.local.m1xxos.me"]
  forward_host            = "192.168.1.100"
  forward_port            = 443
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
  http2_support           = true
  hsts_enabled            = true
  certificate_id          = 1
}


resource "nginxproxymanager_proxy_host" "portainer_proxy" {
  domain_names            = ["portainer.local.m1xxos.me"]
  forward_host            = "192.168.1.99"
  forward_port            = 9443
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
  http2_support           = true
  hsts_enabled            = true
  certificate_id          = 1
}

resource "nginxproxymanager_proxy_host" "gitlab_proxy" {
  domain_names            = ["gitlab.local.m1xxos.me"]
  forward_host            = "192.168.1.228"
  forward_port            = 443
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
  http2_support           = true
  hsts_enabled            = true
  certificate_id          = 1
}

resource "nginxproxymanager_proxy_host" "registry_proxy" {
  domain_names            = ["registry.local.m1xxos.me"]
  forward_host            = "192.168.1.228"
  forward_port            = 443
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
  http2_support           = true
  hsts_enabled            = true
  certificate_id          = 1
}

resource "nginxproxymanager_proxy_host" "home_proxy" {
  domain_names            = ["*.home.m1xxos.me", "home.m1xxos.me"]
  forward_host            = "192.168.1.99"
  forward_port            = 443
  forward_scheme          = "https"
  allow_websocket_upgrade = true
  block_exploits          = true
  ssl_forced              = true
  http2_support           = true
  hsts_enabled            = true
  certificate_id          = 11
}
