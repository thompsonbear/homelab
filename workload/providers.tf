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
    kubectl = {
      source  = "alekc/kubectl"
      version = "3.0.0-beta3"
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
  k8s_client_cert = base64decode(module.akv.secrets["${var.environment}-kubeconfig"].users[0].user.client-certificate-data)
  k8s_client_key  = base64decode(module.akv.secrets["${var.environment}-kubeconfig"].users[0].user.client-key-data)
  k8s_ca_cert     = base64decode(module.akv.secrets["${var.environment}-kubeconfig"].clusters[0].cluster.certificate-authority-data)
}

provider "helm" {
  kubernetes = {
    host                   = local.k8s_host
    client_certificate     = local.k8s_client_cert
    client_key             = local.k8s_client_key
    cluster_ca_certificate = local.k8s_ca_cert
  }
}

provider "kubernetes" {
  host                   = local.k8s_host
  client_certificate     = local.k8s_client_cert
  client_key             = local.k8s_client_key
  cluster_ca_certificate = local.k8s_ca_cert
}

provider "kubectl" {
  host                   = local.k8s_host
  client_certificate     = local.k8s_client_cert
  client_key             = local.k8s_client_key
  cluster_ca_certificate = local.k8s_ca_cert
  load_config_file       = false
}
