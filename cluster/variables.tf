variable "pm_api_token_id" {
  description = "Proxmox API Token ID"
  type = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API Token Secret"
  type = string
  sensitive = true
}
