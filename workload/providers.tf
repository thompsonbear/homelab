terraform {
  backend "azurerm" {}
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
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

provider "helm" {
  kubernetes = {
    host = module.akv.secrets["${var.environment}-kubeconfig"].clusters[0].server
    client_certificate     = base64decode(module.akv.secrets["${var.environment}-kubeconfig"].users[0].client_certificate_data)
    client_key     = base64decode(module.akv.secrets["${var.environment}-kubeconfig"].users[0].client_key_data)
    cluster_ca_certificate = base64decode(module.akv.secrets["${var.environment}-kubeconfig"].clusters[0].certificate_authority_data)
  }
}
