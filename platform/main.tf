locals {
  control_plane_nodes_list = [for vm in var.vms : vm if vm.role == "control-plane"]
  worker_nodes_list        = [for vm in var.vms : vm if vm.role == "worker"]

  control_plane_nodes = { for i, cpn in local.control_plane_nodes_list : "${var.vm_name_prefix}-${var.environment}-cp${i + 1}" => merge(cpn, {
    ip = cidrhost(module.subnets.network_cidr_blocks["control-plane"], i)
  }) }

  worker_nodes = { for i, wn in local.worker_nodes_list : "${var.vm_name_prefix}-${var.environment}-w${i + 1}" => merge(wn, {
    ip = cidrhost(module.subnets.network_cidr_blocks["workers"], i)
  }) }

  all_nodes = merge(local.control_plane_nodes, local.worker_nodes)
}

module "subnets" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = "${var.network.gateway_addr}/${var.network.mask_bits}"
  networks = [
    {
      name     = null
      new_bits = var.network.reserved_mask_bits - var.network.mask_bits
    },
    {
      name     = "kube-vip"
      new_bits = var.network.kube_vip_mask_bits - var.network.mask_bits
    },
    {
      name     = "control-plane"
      new_bits = var.network.control_plane_mask_bits - var.network.mask_bits
    },
    {
      name     = "workers"
      new_bits = var.network.worker_mask_bits - var.network.mask_bits
    }
  ]
}

module "akv" {
  source = "./modules/akv"
  name = var.az_key_vault_name
  resource_group = var.az_key_vault_rg
}

module "unifi" {
  source      = "./modules/unifi"
  environment = var.environment
  network     = var.network
  vms         = local.all_nodes
}

module "pve" {
  depends_on   = [module.unifi]
  source       = "./modules/pve"
  environment  = var.environment
  network      = var.network
  pve_nodes    = var.pve_nodes
  iso_filename = var.talos_iso_filename
  vms          = local.all_nodes
}

module "talos" {
  depends_on          = [module.pve]
  source              = "./modules/talos"
  environment         = var.environment
  talos_version       = var.talos_version
  network             = var.network
  control_plane_nodes = local.control_plane_nodes
  worker_nodes        = local.worker_nodes
  kube_vip            = cidrhost(module.subnets.network_cidr_blocks["kube-vip"], 0)
}

resource "azurerm_key_vault_secret" "talosconfig" {
  name         = "talosconfig"
  value        = module.talos.cluster.talosconfig
  key_vault_id = module.akv.id
}

resource "azurerm_key_vault_secret" "kubeconfig" {
  name         = "kubeconfig"
  value        = module.talos.cluster.kubeconfig
  key_vault_id = module.akv.id
}
