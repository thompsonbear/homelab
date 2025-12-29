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

  workload = {
    core = {
      cnpg-operator = {
        namespace     = "cnpg"
        privileged    = true
        chart_repo    = "https://cloudnative-pg.github.io/charts"
        chart_name    = "cloudnative-pg"
        chart_version = "0.26.1"

      }
      metallb = {
        namespace     = "metallb",
        privileged    = true
        chart_repo    = "https://metallb.github.io/metallb"
        chart_name    = "metallb"
        chart_version = "0.15.2"
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
        }
      }
      cert-manager = {
        namespace     = "cert-manager"
        privileged    = true
        chart_repo    = "https://charts.jetstack.io"
        chart_name    = "cert-manager"
        chart_version = "1.19.1"
        manifests = {
          cloudflare_token_secret = {
            pre_install   = true
            template_file = "cloudflare-token-secret.yaml.tmpl"
            vars = {
              cloudflare_token = var.cloudflare_token
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
      prometheus-operator-crds = {
        namespace     = "mon"
        chart_repo    = "oci://ghcr.io/prometheus-community/charts"
        chart_name    = "prometheus-operator-crds"
        chart_version = "25.0.0"
      }
    }
    ingress = {
      traefik = {
        namespace     = "traefik"
        privileged    = true
        chart_repo    = "https://traefik.github.io/charts"
        chart_name    = "traefik"
        chart_version = "37.3.0"
      }
    }
    storage = {
      longhorn = {
        namespace     = "longhorn-system"
        privileged    = true
        chart_repo    = "https://charts.longhorn.io"
        chart_name    = "longhorn"
        chart_version = "1.10.1"
        auth_type     = "oauth_proxy"
        fqdn          = "longhorn.bear.fyi"
      }
    }
    idp = {
      keycloak = {
        namespace     = "keycloak"
        chart_repo    = "oci://registry-1.docker.io/cloudpirates"
        chart_name    = "keycloak"
        chart_version = "0.8.7"
        db = {
          size      = "10Gi"
          wal       = "5Gi"
          instances = 2
        }
        set = [{
          name  = "keycloak.adminPassword"
          value = random_password.admin_password.result
        }]
      }
    }
    app = {
      prometheus = {
        namespace     = "mon"
        privileged    = true
        chart_repo    = "oci://ghcr.io/prometheus-community/charts"
        chart_name    = "prometheus"
        chart_version = "27.50.0"
        auth_type     = "oauth_proxy"
        fqdn          = "prom.bear.fyi"
      }
      grafana = {
        namespace     = "mon"
        chart_repo    = "https://grafana.github.io/helm-charts"
        chart_name    = "grafana"
        chart_version = "10.3.0"
        auth_type     = "oauth"
        oauth_config = {
          redirect_uris = ["https://grafana.bear.fyi/login/generic_oauth"]
          logout_uris   = ["https://grafana.bear.fyi/*"]
          client_secret = random_password.grafana_client_secret.result
          client_roles  = ["admin", "editor", "viewer"]
        }
        manifests = {
          grafana_admin_creds = {
            pre_install   = true
            template_file = "basic-auth.yaml.tmpl"
            vars = {
              name      = "grafana-admin-creds"
              namespace = "mon"
              username  = "bear-admin"
              password  = random_password.admin_password.result
            }
          }

        }
        set = [{
          name  = "grafana\\.ini.auth\\.generic_oauth.client_secret"
          value = random_password.grafana_client_secret.result
        }]
      }
      ejbca = {
        namespace     = "ejbca"
        chart_repo    = "oci://repo.keyfactor.com/charts"
        chart_name    = "ejbca-ce"
        chart_version = "9.1.1"
        auth_type     = "oauth_proxy"
        fqdn          = "ejbca.bear.fyi"
        db = {
          size      = "10Gi"
          wal       = "1Gi"
          instances = 2
        }
      }
      bluesky-pds = {
        namespace     = "bluesky-pds"
        chart_repo    = "https://charts.bear.fyi"
        chart_name    = "bluesky-pds"
        chart_version = "0.4.193"
        set = [{
          name  = "pds.config.secrets.emailSmtpUrl"
          value = "smtps://apikey:${var.sendgrid_api_key}@smtp.sendgrid.net:465"
        }]
      }
      home-assistant = {
        namespace     = "home-assistant"
        chart_repo    = "https://pajikos.github.io/home-assistant-helm-chart/"
        chart_name    = "home-assistant"
        chart_version = "0.3.36"
      }
      # nextcloud = {
      #   namespace     = "nextcloud"
      #   chart_repo    = "https://nextcloud.github.io/helm"
      #   chart_name    = "nextcloud"
      #   chart_version = "8.7.0"
      #   auth_type     = "oauth"
      #   oauth_config = {
      #     redirect_uris = ["https://cloud.bear.fyi/apps/sociallogin/custom_oidc/keycloak"]
      #     logout_uris   = ["https://cloud.bear.fyi/*"]
      #     client_roles  = ["admin", "user"]
      #   }
      #   set = [{
      #     name  = "nextcloud.password"
      #     value = random_password.admin_password.result
      #   }]
      #   db = {
      #     size      = "50Gi"
      #     wal       = "10Gi"
      #     instances = 1
      #   }
      #   kv = {
      #     instances = 1
      #     size      = "10Gi"
      #   }
      # }
      immich = {
        namespace     = "immich"
        chart_repo    = "https://secustor.dev/helm-charts"
        chart_name    = "immich"
        chart_version = "1.0.9"
        auth_type     = "oauth"
        oauth_config = {
          redirect_uris          = [
            "https://immich.bear.fyi/auth/login",
            "https://immich.bear.fyi/user-settings",
            "app.immich:///oauth-callback"
          ]
          logout_uris            = ["https://immich.bear.fyi/*"]
          client_roles           = ["admin", "user"]
          prefix_role_claim      = false
          multivalued_role_claim = false
          client_secret  = random_password.immich_client_secret.result
        }
        manifests = {
          immich-config = {
            pre_install   = true
            template_file = "immich-config.yaml.tmpl"
            vars = {
              client_secret  = random_password.immich_client_secret.result
              namespace = "immich"
              smtp_apikey = var.sendgrid_api_key
            }
          }
        }
        db = {
          size      = "20Gi"
          wal       = "2Gi"
          instances = 1
        }
        kv = {
          instances = 1
          size      = "10Gi"
        }
      }
    }
  }
}
