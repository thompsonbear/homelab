variable "insecure" {
  type    = bool
  default = false
}

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
  })
  description = "the deployment network details"

  validation {
    condition     = var.network.mask_bits > 0 && var.network.mask_bits < 32
    error_message = "mask_bits must be a number within 0 and 32"
  }
}

variable "pve_nodes" {
  type = map(object({
    vm_network = optional(
      object({
        bridge_iface = optional(string, "vmbr0")
        iface_model  = optional(string, "virtio")
      }),
      {
        bridge_iface = "vmbr0"
        iface_model  = "virtio"
      }
    )
    vm_storage = object({
      disk = string
      iso  = string
      init = string
    })
  }))
}

variable "iso_filename" {
  type = string
}

variable "vms" {
  type = map(object({
    ip           = string
    vcores       = number
    role         = string
    ram_mb       = number
    os_disk_gb   = number
    data_disk_gb = optional(number, 0)
    pve_node     = optional(string)
  }))
}
