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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
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

locals {
  k8s_host        = module.akv.secrets["${var.environment}-kubeconfig"].clusters[0].cluster.server
  k8s_client_cert = base64decode(module.akv.secrets["${var.environment}-kubeconfig"].users[0].user.client_certificate_data)
  k8s_client_key  = base64decode(module.akv.secrets["${var.environment}-kubeconfig"].users[0].user.client_key_data)
  k8s_ca_cert     = base64decode(module.akv.secrets["${var.environment}-kubeconfig"].clusters[0].cluster.certificate_authority_data)
}

provider "helm" {
  kubernetes = {
    insecure = true
    host                   = local.k8s_host
    client_certificate     = local.k8s_client_cert
    client_key             = local.k8s_client_key
    cluster_ca_certificate = local.k8s_ca_cert
  }
}

provider "kubernetes" {
  insecure = true
  host                   = local.k8s_host
  client_certificate     = local.k8s_client_cert
  client_key             = local.k8s_client_key
  cluster_ca_certificate = local.k8s_ca_cert
}
