variable "pm_api_token_id" {
  description = "Proxmox API Token ID"
  type = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API Token Secret"
  type = string
  sensitive = true
}

variable "ui_api_key" {
  description = "Unifi API Key (Network > Settings > Control Plane > Integrations)"
  type = string
  sensitive = true
}

variable "insecure" {
  description = "Whether to use an insecure tls connection"
  type = bool
}
