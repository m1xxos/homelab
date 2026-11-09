# OpenWrt Network and Firewall configuration for Cluster VLAN

locals {
  enable_openwrt = var.vlan_id != null && var.manage_openwrt
}

# 1. 802.1q VLAN device on top of the base device (e.g. br-lan)
resource "openwrt_network_device" "cluster_vlan" {
  count = local.enable_openwrt ? 1 : 0

  id     = "br_lan_${var.vlan_id}"
  name   = "${var.openwrt_base_device}.${var.vlan_id}"
  type   = "8021q"
  ifname = var.openwrt_base_device
  vid    = var.vlan_id
}

# 2. OpenWrt logical network interface for the cluster
resource "openwrt_network_interface" "cluster" {
  count = local.enable_openwrt ? 1 : 0

  id      = var.cluster_name
  device  = openwrt_network_device.cluster_vlan[0].name
  proto   = "static"
  ipaddr  = var.default_gateway
  netmask = var.vlan_netmask
}

# 3. OpenWrt firewall zone for the cluster
resource "openwrt_firewall_zone" "cluster" {
  count = local.enable_openwrt ? 1 : 0

  id      = var.cluster_name
  name    = var.cluster_name
  network = [openwrt_network_interface.cluster[0].id]
  input   = "ACCEPT"
  output  = "ACCEPT"
  forward = "REJECT"
}

resource "openwrt_firewall_forwarding" "lan_to_cluster" {
  count = local.enable_openwrt ? 1 : 0

  src    = "lan"
  dest   = openwrt_firewall_zone.cluster[0].name
  family = "ipv4"
}

resource "openwrt_firewall_forwarding" "cluster_to_wan" {
  count = local.enable_openwrt ? 1 : 0

  src    = openwrt_firewall_zone.cluster[0].name
  dest   = "wan"
  family = "ipv4"
}

resource "openwrt_firewall_forwarding" "cluster_to_lan" {
  count = local.enable_openwrt ? 1 : 0

  src    = openwrt_firewall_zone.cluster[0].name
  dest   = "lan"
  family = "ipv4"
}
