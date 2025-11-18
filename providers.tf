terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.2-rc05"
    }
    talos = {
      source = "siderolabs/talos"
      version = "0.9.0"
    }
  }
}

provider "proxmox" {
  pm_api_url = "https://172.21.0.8:8006/api2/json"
  pm_tls_insecure = true
  pm_api_token_id = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
}



