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
