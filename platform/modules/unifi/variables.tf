variable "environment" {
  type = string
}

variable "network" {
  type = object({
    mask_bits         = number
    gateway_addr      = string
    vlan_tag          = number
    dns_server_list   = list(string)
    dns_search_domain = string
    firewall_zone     = string
  })
  description = "the deployment network details"

  validation {
    condition     = var.network.mask_bits > 0 && var.network.mask_bits < 32
    error_message = "mask_bits must be a number within 0 and 32"
  }
}

variable "vms" {
  type = map(object({
    ip = string
  }))
}
