resource "talos_machine_secrets" "this" {}

data "talos_image_factory_extensions_versions" "this" {
  talos_version = "v1.11.5"
  filters = {
    names = [
      "qemu-guest-agent",
      "iscsi-tools",
      "util-linux-tools"
    ]
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info.*.name
        }
      }
    }
  )
}

data "talos_image_factory_urls" "this" {
  talos_version = "1.11.5"
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "nocloud"
  architecture  = "amd64"
}

data "talos_machine_configuration" "controlplanes_config" {
  cluster_name     = local.cluster.name
  cluster_endpoint = local.kube_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "workers_config" {
  cluster_name     = local.cluster.name
  cluster_endpoint = local.kube_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = local.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in local.vm.nodes : v.ipv4 if v.type.k8s_role == "control-plane"]
}

resource "talos_machine_configuration_apply" "controlplanes_config_apply" {
  depends_on                  = [time_sleep.wait_20s_for_vm_boot]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplanes_config.machine_configuration
  for_each                    = { for k, v in local.vm.nodes : k => v if v.type.k8s_role == "control-plane" }
  node                        = each.value.ipv4

  config_patches = [
    yamlencode({
      machine = {
        install = {
          image = "${data.talos_image_factory_urls.this.urls.installer}"
          disk  = "/dev/vda"
        }
        kubelet = {
          extraMounts = [{
            destination = "/var/lib/longhorn"
            type        = "bind"
            source      = "/var/lib/longhorn"
            options     = ["bind", "rshared", "rw"]
          }]
        }
        network = {
          hostname = each.key
          interfaces = [{
            interface = "eth0"
            dhcp      = false
            vip = {
              ip = "${local.cluster.vip}"
            }
          }]
          nameservers   = local.vm.network.dns_servers
          searchDomains = [local.vm.network.localdomain]
          extraHostEntries = [{
            ip = each.value.ipv4
            aliases = [
              each.key,
              "${each.key}.${local.vm.network.localdomain}"
            ]
          }]
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "workers_config_apply" {
  depends_on                  = [time_sleep.wait_20s_for_vm_boot]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.workers_config.machine_configuration
  for_each                    = { for k, v in local.vm.nodes : k => v if v.type.k8s_role == "worker" }
  node                        = each.value.ipv4

  config_patches = [
    yamlencode({
      machine = {
        install = {
          image = "${data.talos_image_factory_urls.this.urls.installer}"
          disk  = "/dev/vda"
        }
        kubelet = {
          extraMounts = [{
            destination = "/var/lib/longhorn"
            type        = "bind"
            source      = "/var/lib/longhorn"
            options     = ["bind", "rshared", "rw"]
          }]
        }
        network = {
          hostname      = each.key
          nameservers   = local.vm.network.dns_servers
          searchDomains = [local.vm.network.localdomain]
          extraHostEntries = [{
            ip = each.value.ipv4
            aliases = [
              each.key,
              "${each.key}.${local.vm.network.localdomain}"
            ]
          }]
        }
      }
    })
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplanes_config_apply]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in local.vm.nodes : v.ipv4 if v.type.k8s_role == "control-plane"][0]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in local.vm.nodes : v.ipv4 if v.type.k8s_role == "control-plane"][0]
}

data "talos_cluster_health" "this" {
  depends_on = [talos_machine_bootstrap.this, talos_cluster_kubeconfig.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes  = [for k, v in local.vm.nodes : v.ipv4 if v.type.k8s_role == "control-plane"]
  endpoints            = [for k, v in local.vm.nodes : v.ipv4 if v.type.k8s_role == "control-plane"]
  worker_nodes         = [for k, v in local.vm.nodes : v.ipv4 if v.type.k8s_role == "worker"]
}
