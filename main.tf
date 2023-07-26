terraform {
  required_providers {
    unifi = {
      source  = "akerl/unifi"
      version = "0.41.7"
    }
  }
}

provider "unifi" {
  api_url = "https://gateway.infra.home.a-rwx.org"
}

locals {
  yaml    = yamldecode(file("${path.module}/data.yaml"))
  clients = { for ip, client in local.yaml.clients : client.mac => merge(client, { "ip" = ip }) }
  devices = { for mac, client in local.clients : mac => client if client.network == "Infra" }
  wans    = local.yaml.wans
  lans    = local.yaml.lans
  wifi    = local.yaml.wifi
}

data "unifi_ap_group" "default" {
}

data "unifi_user_group" "default" {
}

resource "unifi_network" "wans" {
  for_each = local.wans

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
  for_each = local.lans

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
#  for_each = local.wifi
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
  name     = "${lower(each.value.network)}.${each.value.hostname}"
  fixed_ip = each.value.ip
}

resource "unifi_port_profile" "network" {
  for_each = unifi_network.lans

  name                  = each.value.name
  poe_mode              = "auto"
  forward               = each.value.name == "Infra" ? "customize" : "native"
  native_networkconf_id = each.value.id
}

resource "unifi_device" "devices" {
  for_each = local.devices

  mac  = each.key
  name = each.value.hostname

  dynamic "port_override" {
    for_each = {
      for mac, client in local.clients : client.port => client
      if lookup(client, "upstream", null) == each.value.hostname
    }

    content {
      number              = port_override.key
      name                = "${lower(port_override.value.network)}.${port_override.value.hostname}"
      native_network_id   = contains(keys(port_override.value), "agg_count") ? unifi_network.lans[port_override.value.network].id : null
      port_profile_id     = contains(keys(port_override.value), "agg_count") ? null : unifi_port_profile.network[port_override.value.network].id
      op_mode             = contains(keys(port_override.value), "agg_count") ? "aggregate" : "switch"
      aggregate_num_ports = contains(keys(port_override.value), "agg_count") ? port_override.value.agg_count : null
    }
  }
}

output "site_addresses" {
  value = { for i, x in local.clients : x.ip => "${x.hostname}.${lower(x.network)}" }
}
