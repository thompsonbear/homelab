variable "az_key_vault_name" {
  type        = string
  description = "Name of the Azure Key Vault to reference for secret values"
  sensitive   = true
}

variable "az_key_vault_rg" {
  type        = string
  description = "Resource Group containing the target Azure Key Vault"
  sensitive   = true
}

variable "environment" {
  type        = string
  description = "The environment type (prod/staging/dev/etc.)"
}

variable "network" {
  type = object({
    mask_bits               = number
    gateway_addr            = string
    vlan_tag                = number
    dns_server_list         = list(string)
    dns_search_domain       = string
    firewall_zone           = string
    reserved_mask_bits      = optional(number, 29) # 8 hosts
    kube_vip_mask_bits      = optional(number, 31) # 2 hosts
    control_plane_mask_bits = optional(number, 29) # 8 hosts
    worker_mask_bits        = optional(number, 27) # 32 hosts
  })
}

variable "pve_nodes" {
  type = map(object({
    vm_network = optional(object({
      bridge_iface = optional(string)
      iface_model  = optional(string)
    }))
    vm_storage = object({
      disk = string
      iso  = string
      init = string
    })
  }))
}

variable "vm_name_prefix" {
  type = string
}

variable "vms" {
  type = list(object({
    id           = optional(number)
    pve_node     = optional(string)
    vcores       = number
    ram_mb       = number
    os_disk_gb   = optional(number, 64)
    data_disk_gb = optional(number)
    role         = string
  }))

  validation {
    condition     = alltrue([for vm in var.vms : vm.role == "worker" || vm.role == "control-plane"])
    error_message = "vm roles must be set to either 'worker' or 'control-plane'"
  }
}

variable "talos_version" {
  type = string
}

variable "talos_iso_filename" {
  type = string
}
