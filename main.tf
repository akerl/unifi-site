terraform {
  required_providers {
    unifi = {
      source  = "paultyng/unifi"
      version = "0.41.0"
    }
  }
}

provider "unifi" {
  api_url = "https://gateway.infra.home.a-rwx.org"
}

locals {
  clients_csv = csvdecode(file("${path.module}/clients.csv"))
  clients     = { for client in local.clients_csv : client.mac => client }
}

data "unifi_ap_group" "default" {
}

data "unifi_user_group" "default" {
}

resource "unifi_network" "wans" {
  for_each = var.wans

  name          = each.key
  purpose       = "wan"
  network_group = ""


  wan_networkgroup    = each.value.group
  wan_type            = "dhcp"
  wan_type_v6         = "disabled"
  wan_dns             = ["8.8.8.8", "8.8.4.4"]
  wan_dhcp_v6_pd_size = 48
}

resource "unifi_network" "lans" {
  for_each = var.lans

  name    = each.key
  purpose = "corporate"

  subnet      = each.value.subnet
  vlan_id     = each.value.vlan_id
  domain_name = each.value.domain_name

  dhcp_start   = each.value.dhcp_start
  dhcp_stop    = each.value.dhcp_stop
  dhcp_enabled = true
  dhcp_dns     = ["8.8.8.8", "8.8.4.4"]

  igmp_snooping = false
  multicast_dns = each.value.multicast_dns
}

#resource "unifi_wlan" "wifi" {
#  for_each = var.wifi
#
#  name       = each.key
#  security   = "wpapsk"
#
#  is_guest   = each.value.is_guest
#  network_id = unifi_network.lans[each.value.network_name].id
#
#  no2ghz_oui           = each.value.band_steering
#  uapsd                = each.value.uapsd
#  fast_roaming_enabled = each.value.fast_roaming_enabled
#  pmf_mode             = each.value.pmf_mode
#  wpa3_support         = each.value.wpa3_support
#  wpa3_transition      = each.value.wpa3_support
#
#  ap_group_ids  = [data.unifi_ap_group.default.id]
#  user_group_id = data.unifi_user_group.default.id
#}

resource "unifi_user" "clients" {
  for_each = local.clients

  mac      = each.key
  name     = "${each.value.network}.${each.value.hostname}"
  fixed_ip = each.value.ip
}

resource "unifi_port_profile" "disabled" {
  name = "Disabled"

  poe_mode = "off"
  forward  = "disabled"
}

resource "unifi_port_profile" "network" {
  for_each = var.lans

  poe_mode              = "auto"
  native_networkconf_id = unifi_network.lans[each.key].id
}
