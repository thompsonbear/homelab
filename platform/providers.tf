terraform {
  backend "azurerm" {}
  required_providers {
    unifi = {
      source  = "filipowm/unifi"
      version = "1.1.0"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.0.0"
    }
  }
}

provider "azurerm" {
  use_oidc = true
  features {
    enhanced_validation {
      preflight_enabled = true
    }
  }
}

provider "proxmox" {
  pm_api_url          = module.akv.secrets.pve.url
  pm_tls_insecure     = true
  pm_api_token_id     = module.akv.secrets.pve.token_id
  pm_api_token_secret = module.akv.secrets.pve.token_secret
}

provider "unifi" {
  api_key        = module.akv.secrets.unifi.api_key
  api_url        = module.akv.secrets.unifi.api_url
  allow_insecure = true
}
