terraform {
  required_providers {
    unifi = {
      source = "ubiquiti-community/unifi"
      version = "0.41.3"
    }
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.2-rc05"
    }
    talos = {
      source = "siderolabs/talos"
      version = "0.9.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "3.1.1"
    }
  }
}

provider "unifi" {
  api_key = var.ui_api_key
  api_url = "https://172.21.0.1/"
  allow_insecure = var.insecure
}

provider "proxmox" {
  pm_api_url = "https://172.21.0.8:8006/api2/json"
  pm_tls_insecure = var.insecure
  pm_api_token_id = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
}

provider "helm" {
  kubernetes = {
    host = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
    client_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    insecure = var.insecure
  }
}
