variable "wans" {
  type = map(object({
    group = string
  }))
  default = {
    Shentel = {
      group = "WAN"
    },
    Tello = {
      group = "WAN2"
    },
  }
}

variable "lans" {
  type = map(object({
    subnet        = string
    vlan_id       = number
    domain_name   = string
    dhcp_start    = string
    dhcp_stop     = string
    multicast_dns = bool
  }))
  default = {
    Infra = {
      subnet        = "10.0.0.0/24"
      vlan_id       = 0
      domain_name   = "infra.home.a-rwx.org"
      dhcp_start    = "10.0.0.150"
      dhcp_stop     = "10.0.0.250"
      multicast_dns = false
    },
    Servers = {
      subnet        = "10.0.1.0/24"
      vlan_id       = 101
      domain_name   = "servers.home.a-rwx.org"
      dhcp_start    = "10.0.1.200"
      dhcp_stop     = "10.0.1.250"
      multicast_dns = true
    },
    Security = {
      subnet        = "10.0.2.0/24"
      vlan_id       = 102
      domain_name   = "security.home.a-rwx.org"
      dhcp_start    = "10.0.2.200"
      dhcp_stop     = "10.0.2.250"
      multicast_dns = false
    },
    IoT = {
      subnet        = "172.16.0.0/22"
      vlan_id       = 700
      domain_name   = "iot.home.a-rwx.org"
      dhcp_start    = "172.16.3.200"
      dhcp_stop     = "172.16.3.250"
      multicast_dns = true
    },
    Gaming = {
      subnet        = "172.16.20.0/24"
      vlan_id       = 720
      domain_name   = "gaming.home.a-rwx.org"
      dhcp_start    = "172.16.20.200"
      dhcp_stop     = "172.16.20.250"
      multicast_dns = false
    },
    Standard = {
      subnet        = "192.168.1.0/24"
      vlan_id       = 900
      domain_name   = "standard.home.a-rwx.org"
      dhcp_start    = "192.168.1.200"
      dhcp_stop     = "192.168.1.250"
      multicast_dns = true
    },
    Guest = {
      subnet        = "192.168.99.0/24"
      vlan_id       = 999
      domain_name   = "guest.home.a-rwx.org"
      dhcp_start    = "192.168.99.200"
      dhcp_stop     = "192.168.99.250"
      multicast_dns = false
    },
  }
}

variable "wifi" {
  type = map(object({
    network_name         = string
    is_guest             = bool
    band_steering        = bool
    uapsd                = bool
    fast_roaming_enabled = bool
    pmf_mode             = string
    wpa3_support         = bool
  }))
  default = {
    akerl = {
      network_name         = "Standard"
      is_guest             = false
      band_steering        = true
      uapsd                = true
      fast_roaming_enabled = true
      pmf_mode             = "optional"
      wpa3_support         = true
    },
    akerl_guest = {
      network_name         = "Guest"
      is_guest             = false
      band_steering        = false
      uapsd                = false
      fast_roaming_enabled = true
      pmf_mode             = "optional"
      wpa3_support         = true
    },
    akerl_iot = {
      network_name         = "IoT"
      is_guest             = false
      band_steering        = false
      uapsd                = false
      fast_roaming_enabled = false
      pmf_mode             = "disabled"
      wpa3_support         = false
    },
  }
}
