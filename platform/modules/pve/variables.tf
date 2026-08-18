variable "insecure" {
  type    = bool
  default = false
}

variable "environment" {
  type = string
}

variable "subnet" {
  type        = string
  description = "The network subnet in cidr notation with the gateway address (e.g. 10.0.0.1/24)"
}

variable "vlan_tag" {
  type        = number
  description = "The VLAN tag for the vm network (e.g. 100)"
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
