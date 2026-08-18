variable "environment" {
  type = string
}

variable "subnet" {
  type        = string
  description = "The network subnet in cidr notation with the gateway address (e.g. 10.0.0.1/24)"
}

variable "vlan_tag" {
  type        = number
  description = "The VLAN tag for the network (e.g. 100)"
}

variable "dns_search_domain" {
  type        = string
  description = "The DNS search domain for the network (e.g. example.local)"
}

variable "firewall_zone" {
  type        = string
  description = "The firewall zone for the network (e.g. internal)"
}

variable "vms" {
  type = map(object({
    ip = string
  }))
}
