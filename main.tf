terraform {
  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "0.55.0"
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
  ports   = local.yaml.ports
  v4_dns  = ["8.8.8.8", "8.8.4.4"]
  v6_dns  = ["2001:4860:4860::8888", "2001:4860:4860::8844"]
}

data "unifi_ap_group" "default" {
  name = "All APs"
}

data "unifi_client_qos_rate" "default" {
  name = "Default"
}

resource "unifi_wan" "wans" {
  for_each = local.wans

  name         = each.key
  networkgroup = each.value.group
  type         = "dhcp"
  type_v6      = "disabled"
  dns = {
    preference = "manual"
    primary    = local.v4_dns[0]
    secondary  = local.v4_dns[1]
  }
}

resource "unifi_network" "lans" {
  for_each = local.lans

  name               = each.key
  purpose            = "corporate"
  auto_scale         = false
  setting_preference = "manual"

  subnet      = each.value.subnet
  vlan        = each.value.vlan_id == 0 ? null : each.value.vlan_id
  domain_name = each.value.domain_name

  dhcp_server = {
    enabled     = true
    start       = each.value.dhcp_start
    stop        = each.value.dhcp_stop
    dns_enabled = true
    dns_servers = local.v4_dns
  }

  dhcp_v6_server = {
    enabled     = false
    dns_auto    = false
    dns_servers = local.v6_dns
    start       = "::2"
    stop        = "::7d1"
    lease       = 86400
  }

  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"
  ipv6_ra_priority = "high"

  igmp_snooping = false
  multicast_dns = each.value.multicast_dns
}

resource "unifi_wlan" "wifi" {
  for_each = local.wifi

  name       = each.key
  security   = "wpapsk"
  passphrase = ""

  is_guest   = each.value.is_guest
  network_id = unifi_network.lans[each.value.network_name].id

  no2ghz_oui           = each.value.band_steering
  uapsd                = each.value.uapsd
  fast_roaming_enabled = each.value.fast_roaming_enabled
  pmf_mode             = each.value.pmf_mode
  wpa3_support         = each.value.wpa3_support
  wpa3_transition      = each.value.wpa3_support
  wpa3_fast_roaming    = each.value.wpa3_support
  bss_transition       = true
  group_rekey          = 3600

  ap_group_ids  = [data.unifi_ap_group.default.id]
  user_group_id = data.unifi_client_qos_rate.default.id
}

resource "unifi_client" "clients" {
  for_each = local.clients

  mac      = each.key
  name     = "${lower(each.value.network)}.${each.value.hostname}"
  fixed_ip = each.value.ip
}

resource "unifi_port_profile" "network" {
  for_each = unifi_network.lans

  name                   = each.value.name
  poe_mode               = "auto"
  forward                = each.value.name == "Infra" ? "customize" : "native"
  native_networkconf_id  = each.value.id
  setting_preference     = "manual"
  tagged_vlan_mgmt       = each.value.name == "Infra" ? "auto" : "block_all"
  lldpmed_notify_enabled = false
}

resource "unifi_port_profile" "ports" {
  for_each = local.ports

  name                     = each.key
  poe_mode                 = "auto"
  forward                  = "customize"
  setting_preference       = "manual"
  tagged_vlan_mgmt         = "custom"
  lldpmed_notify_enabled   = false
  native_networkconf_id    = unifi_network.lans[each.value.native].id
  excluded_networkconf_ids = [for x in unifi_network.lans : x.id if !contains(each.value.allowed, x.name) && x.name != each.value.native]
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
      index                 = port_override.key
      name                  = "${lower(port_override.value.network)}.${port_override.value.hostname}"
      native_networkconf_id = contains(keys(port_override.value), "agg_members") ? unifi_network.lans[port_override.value.network].id : null
      port_profile_id       = contains(keys(port_override.value), "agg_members") ? null : contains(keys(port_override.value), "profile") ? unifi_port_profile.ports[port_override.value.profile].id : unifi_port_profile.network[port_override.value.network].id
      op_mode               = contains(keys(port_override.value), "agg_members") ? "aggregate" : "switch"
      aggregate_members     = contains(keys(port_override.value), "agg_members") ? port_override.value.agg_members : null
    }
  }
}

output "site_addresses" {
  value = { for i, x in local.clients : x.ip => "${x.hostname}.${lower(x.network)}" }
}
