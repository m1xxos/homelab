resource "openwrt_network_device" "k8s_vlan" {
  id     = "br_lan_20"
  name   = "br-lan.20"
  type   = "8021q"
  ifname = "br-lan"
  vid    = 20
}

resource "openwrt_network_interface" "k8s" {
  id      = "k8s"
  device  = openwrt_network_device.k8s_vlan.name
  proto   = "static"
  ipaddr  = "192.168.20.1"
  netmask = "255.255.255.0"
}

resource "openwrt_firewall_zone" "k8s" {
  id      = "k8s"
  name    = "k8s"
  network = [openwrt_network_interface.k8s.id]
  input   = "ACCEPT"
  output  = "ACCEPT"
  forward = "REJECT"
}

# Allow LAN clients to connect to cluster nodes, VIP and services
resource "openwrt_firewall_forwarding" "lan_to_k8s" {
  src    = "lan"
  dest   = openwrt_firewall_zone.k8s.name
  family = "ipv4"
}

# Allow cluster nodes to access WAN (Internet)
resource "openwrt_firewall_forwarding" "k8s_to_wan" {
  src    = openwrt_firewall_zone.k8s.name
  dest   = "wan"
  family = "ipv4"
}

# Allow cluster nodes to access LAN resources (e.g. NFS at 192.168.1.138, MinIO at 192.168.1.77, Proxmox at 192.168.1.122)
resource "openwrt_firewall_forwarding" "k8s_to_lan" {
  src    = openwrt_firewall_zone.k8s.name
  dest   = "lan"
  family = "ipv4"
}
