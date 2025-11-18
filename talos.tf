locals {
  cluster_name = "bear"
  cluster_endpoint = "https://172.21.8.11:6443" # Node 1 ipv4 (cluster needs to bootstrap before vip is available)
}

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplanes_config" {
    cluster_name = local.cluster_name
    cluster_endpoint = local.cluster_endpoint
    machine_type = "controlplane"
    machine_secrets = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "workers_config" {
    cluster_name = local.cluster_name
    cluster_endpoint = local.cluster_endpoint
    machine_type = "worker"
    machine_secrets = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name  = local.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [for k, v in local.cluster_nodes : v.ipv4 if v.type.k8s_role == "control-plane"]
}

resource "talos_machine_configuration_apply" "controlplanes_config_apply" {
  depends_on = [time_sleep.wait_20s_for_vm_boot]
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplanes_config.machine_configuration
  for_each = { for k, v in local.cluster_nodes : k => v if v.type.k8s_role == "control-plane" }
  node = each.value.ipv4

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
        }
        network = {
          hostname = each.key
          interfaces = [{
            interface = "eth0"
            dhcp = false
            vip = {
              ip = "172.21.8.10"
            }
          }]
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "workers_config_apply" {
  depends_on = [time_sleep.wait_20s_for_vm_boot]
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.workers_config.machine_configuration
  for_each = { for k, v in local.cluster_nodes : k => v if v.type.k8s_role == "worker" }
  node = each.value.ipv4
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
        }
        network = {
          hostname = each.key
        }
      }
    })
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplanes_config_apply]

  client_configuration  = talos_machine_secrets.this.client_configuration
  node = [for k, v in local.cluster_nodes : v.ipv4 if v.type.k8s_role == "control-plane"][0]
  
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration  = talos_machine_secrets.this.client_configuration
  node = [for k, v in local.cluster_nodes : v.ipv4 if v.type.k8s_role == "control-plane"][0]
}

data "talos_cluster_health" "cluster_health" {
  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes = [for k, v in local.cluster_nodes : v.ipv4 if v.type.k8s_role == "control-plane"] 
  endpoints = [for k, v in local.cluster_nodes : v.ipv4 if v.type.k8s_role == "control-plane"]
  worker_nodes = [for k, v in local.cluster_nodes : v.ipv4 if v.type.k8s_role == "worker"]
}
