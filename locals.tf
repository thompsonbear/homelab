locals {
  vm = {
    network = {
      mask_bits   = "24"
      gateway     = "172.21.8.1"
      dns_servers = ["172.21.8.1"]
      localdomain = "bear.home"
    }
    nodes = {
      bear-cp1 = { vmid = 811, ipv4 = "172.21.8.11", type = local.vm_types.control-plane }
      bear-cp2 = { vmid = 812, ipv4 = "172.21.8.12", type = local.vm_types.control-plane }
      bear-cp3 = { vmid = 813, ipv4 = "172.21.8.13", type = local.vm_types.control-plane }
      bear-w1  = { vmid = 821, ipv4 = "172.21.8.21", type = local.vm_types.worker }
      bear-w2  = { vmid = 822, ipv4 = "172.21.8.22", type = local.vm_types.worker }
      bear-w3  = { vmid = 823, ipv4 = "172.21.8.23", type = local.vm_types.worker }
      bear-w4  = { vmid = 824, ipv4 = "172.21.8.24", type = local.vm_types.worker }
    }
  }
  vm_types = {
    control-plane = { cores = 3, ram = 4096, disk_size = "128G", k8s_role = "control-plane" }
    worker        = { cores = 6, ram = 12288, disk_size = "512G", k8s_role = "worker" }
  }

  cluster = {
    name = "bear"
    vip  = "172.21.8.10"
  }

  kube_endpoint = "https://${local.cluster.vip}:6443"

  # Workloads to run in the cluster
  workload = {
    # These manifests are installed before any other applications
    pre_install_manifests = {
      keycloak_admin_password = {
        template_file = "keycloak-admin-password.yaml.tmpl"
        vars = {
          password = var.keycloak_admin_password
        }
      }
      cloudflare_token_secret = {
        template_file = "cloudflare-token-secret.yaml.tmpl"
        vars = {
          cloudflare_token = var.cloudflare_token
        }
      }
    }
    # Core charts and manifests installed first as they have no dependencies
    core = {
      charts = {
        cnpg-operator = {
          namespace     = "cnpg"
          chart_repo    = "https://cloudnative-pg.github.io/charts"
          chart_name    = "cloudnative-pg"
          chart_version = "0.26.1"
        }
        metallb = {
          namespace     = "metallb",
          chart_repo    = "https://metallb.github.io/metallb"
          chart_name    = "metallb"
          chart_version = "0.15.2"
        }
        cert-manager = {
          namespace     = "cert-manager"
          chart_repo    = "https://charts.jetstack.io"
          chart_name    = "cert-manager"
          chart_version = "1.19.1"
        }
      }
      manifests = {
        ipaddresspool = {
          template_file = "ipaddresspool-metallb.yaml.tmpl"
          vars = {
            name       = "bear-pool"
            pool_range = "172.21.8.100-172.21.8.199"
          }
        }
        l2advertisement = {
          template_file = "l2advertisement-metallb.yaml.tmpl"
          vars = {
            name       = "bear-pool"
            pool_range = "172.21.8.100-172.21.8.199"
          }
        }
        letsencrypt_staging = {
          template_file = "letsencrypt-clusterissuer.yaml.tmpl"
          vars = {
            name               = "staging"
            acme_email         = var.acme_email
            base_public_domain = var.base_public_domain
            server             = "https://acme-staging-v02.api.letsencrypt.org/directory"
          }
        }
        letsencrypt_prod = {
          template_file = "letsencrypt-clusterissuer.yaml.tmpl"
          vars = {
            name               = "prod"
            acme_email         = var.acme_email
            base_public_domain = var.base_public_domain
            server             = "https://acme-v02.api.letsencrypt.org/directory"
          }
        }
      }
    }
    # Ingress workload(s) that is/are dependant on core workloads
    ingress = {
      charts = {
        traefik = {
          namespace     = "traefik"
          chart_repo    = "https://traefik.github.io/charts"
          chart_name    = "traefik"
          chart_version = "37.3.0"
        }
      }
    }
    # Storage workload(s) that is/are dependant on ingress and core workloads
    storage = {
      charts = {
        longhorn = {
          namespace     = "longhorn-system"
          chart_repo    = "https://charts.longhorn.io"
          chart_name    = "longhorn"
          chart_version = "1.10.1"
        }
      }
    }
    # Final deployed workloads with optional database init - the db key can be omitted if a database isn't required for the app
    app = {
      charts = {
        keycloak = {
          namespace     = "keycloak"
          chart_repo    = "oci://registry-1.docker.io/cloudpirates"
          chart_name    = "keycloak"
          chart_version = "0.8.7"
          db = {
            size      = "5Gi"
            wal       = "0.5Gi"
            instances = 2
          }
        }
        ejbca = {
          namespace     = "ejbca"
          chart_repo    = "oci://repo.keyfactor.com/charts"
          chart_name    = "ejbca-ce"
          chart_version = "9.1.1"
          db = {
            size      = "10Gi"
            wal       = "1Gi"
            instances = 2
          }
        }
      }
    }
  }
}
