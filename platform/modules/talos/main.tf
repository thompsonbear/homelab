resource "talos_machine_secrets" "this" {}

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = [
      "qemu-guest-agent",
      "iscsi-tools",
      "util-linux-tools",
      "nfs-utils",
      "nfsd"
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
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "nocloud"
  architecture  = "amd64"
}

data "talos_machine_configuration" "controlplanes_config" {
  cluster_name     = var.environment
  cluster_endpoint = "https://${var.kube_vip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "workers_config" {
  cluster_name     = var.environment
  cluster_endpoint = "https://${var.kube_vip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = var.environment
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in var.control_plane_nodes : v.ip]
}

resource "talos_machine_configuration_apply" "controlplanes_config_apply" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplanes_config.machine_configuration
  for_each                    = var.control_plane_nodes
  node                        = each.value.ip
  apply_mode                  = "auto"

  config_patches = [
    yamlencode({
      cluster = {
        apiServer = {
          admissionControl = [{
            name = "PodSecurity"
            configuration = {
              apiVersion = "pod-security.admission.config.k8s.io/v1beta1"
              kind       = "PodSecurityConfiguration"
              exemptions = {
                namespaces = ["mayastor"]
              }
            }
          }]
        }
      }
      machine = {
        install = {
          image = "${data.talos_image_factory_urls.this.urls.installer}"
          disk  = "/dev/vda"
        }
        network = {
          interfaces = [{
            interface = "eth0"
            dhcp      = false
            vip = {
              ip = "${var.kube_vip}"
            }
          }]
          nameservers   = var.dns_servers
          searchDomains = [var.dns_search_domain]
          extraHostEntries = [{
            ip = each.value.ip
            aliases = [
              each.key,
              "${each.key}.${var.dns_search_domain}"
            ]
          }]
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "workers_config_apply" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.workers_config.machine_configuration
  for_each                    = var.worker_nodes
  node                        = each.value.ip
  apply_mode                  = "auto"

  config_patches = [
    yamlencode({
      machine = {
        install = {
          image = "${data.talos_image_factory_urls.this.urls.installer}"
          disk  = "/dev/vda"
        }
        sysctls = {
          "vm.nr_hugepages" = "1024"
        }
        nodeLabels = {
          "openebs.io/engine" = "mayastor"
        }
        kubelet = {
          extraMounts = [{
            destination = "/var/local"
            type        = "bind"
            source      = "/var/local"
            options     = ["bind", "rshared", "rw"]
          }]
        }
        network = {
          nameservers   = var.dns_servers
          searchDomains = [var.dns_search_domain]
          extraHostEntries = [{
            ip = each.value.ip
            aliases = [
              each.key,
              "${each.key}.${var.dns_search_domain}"
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
  node                 = [for k, v in var.control_plane_nodes : v.ip][0]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.control_plane_nodes : v.ip][0]
}

data "talos_cluster_health" "this" {
  depends_on = [talos_machine_bootstrap.this, talos_cluster_kubeconfig.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes  = [for k, v in var.control_plane_nodes : v.ip]
  endpoints            = [for k, v in var.control_plane_nodes : v.ip]
  worker_nodes         = [for k, v in var.worker_nodes : v.ip]
}
