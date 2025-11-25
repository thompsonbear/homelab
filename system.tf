locals {
  app_roles = ["core", "ingress", "storage", "service"]
  system_apps = {
    cnpg-operator = {
      app_role = "core"
      namespace = "cnpg"
      chart_repo = "https://cloudnative-pg.github.io/charts"
      chart_name = "cloudnative-pg"
      chart_version = "0.26.1"
    }
    metallb = {
      app_role = "core"
      namespace = "metallb",
      chart_repo = "https://metallb.github.io/metallb"
      chart_name = "metallb"
      chart_version = "0.15.2"
      post_install_manifests = {
        ipaddresspool = {
          template_file = "ipaddresspool-metallb.yaml.tmpl"
          vars = {
            name = "bear-pool"
            pool_range = "172.21.8.100-172.21.8.199"
          }
        }
        l2advertisement = {
          template_file = "l2advertisement-metallb.yaml.tmpl"
          vars = {
            name = "bear-pool"
            pool_range = "172.21.8.100-172.21.8.199"
          }
        }
      }
    }
    cert-manager = {
      app_role = "core"
      namespace = "cert-manager"
      chart_repo = "https://charts.jetstack.io"
      chart_name = "cert-manager"
      chart_version = "1.19.1"
      post_install_manifests = {
        letsencrypt_staging = {
          template_file = "letsencrypt-clusterissuer.yaml.tmpl"
          vars = {
            name = "staging"
            acme_email = var.acme_email
            base_public_domain = var.base_public_domain
            server = "https://acme-staging-v02.api.letsencrypt.org/directory"
          }
        }
        letsencrypt_prod = {
          template_file = "letsencrypt-clusterissuer.yaml.tmpl"
          vars = {
            name = "prod"
            acme_email = var.acme_email
            base_public_domain = var.base_public_domain
            server = "https://acme-v02.api.letsencrypt.org/directory"
          }
        }
      }
    }
    traefik = {
      app_role = "ingress"
      namespace = "traefik"
      chart_repo = "https://traefik.github.io/charts"
      chart_name = "traefik"
      chart_version = "37.3.0"
    }
    longhorn = {
      app_role = "storage"
      namespace = "longhorn-system"
      chart_repo = "https://charts.longhorn.io"
      chart_name = "longhorn"
      chart_version = "1.10.1"
    }
    keycloak = {
      app_role = "service"
      namespace = "keycloak"
      chart_repo = "oci://registry-1.docker.io/cloudpirates"
      chart_name = "keycloak"
      chart_version = "0.8.7"
      db = {
        size = "5Gi"
        wal = "0.5Gi"
        instances = 2
      }
    }
  }

  # Manifests that need to be applied before other resources are created - ex. Secrets
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

  # Generate flattened list of manifests for post installs
  flattened_post_install_manifests = flatten([
    for app_name, app in local.system_apps : [
      for manifest_name, manifest in try(app.post_install_manifests, {}) : {
        id            = "${app_name}.${manifest_name}"
        app_role      = app.app_role
        template_file = manifest.template_file
        vars          = manifest.vars
      }
    ]
  ])

  # Group flattened manifests so they may be applied in order by app_role
  post_install_manifests_by_role = {
    for role in app_roles :
    role => {
      for m in local.flattened_post_install_manifests :
      m.id => {
        template_file = m.template_file
        vars          = m.vars
      }
      if m.app_role == role
    }
  }
}

# Create all privileged namespaces for system apps
resource "kubectl_manifest" "create_system_namespaces" {
  depends_on = [data.talos_cluster_health.this]
  for_each = local.system_apps

  yaml_body = templatefile("./system/templates/privileged-namespace.yaml.tmpl", {
    namespace = each.value.namespace
    name = "${each.key}-system"
  })
}

# Apply all crds located in ./system/crds
# Required for any custom resources to be applied by the pre_apply_system_manifests resource
resource "kubectl_manifest" "pre_apply_system_crds" {
  depends_on = [data.talos_cluster_health.this]
  for_each = fileset ("./system/crds/", "*.yaml")

  yaml_body = file("./system/crds/${each.value}")
}

# Apply manifests that are required before other resources are created
# If a custom resource is used, the crd must be added to ./system/crds
resource "kubectl_manifest" "pre_apply_system_manifests" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.create_system_namespaces, kubectl_manifest.pre_apply_system_crds]
  for_each = local.pre_install_manifests

  yaml_body = templatefile("./system/templates/${each.value.template_file}", { vars = each.value.vars })
}

# ---- Install core system apps -----
resource "helm_release" "install_core_system_apps" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.pre_apply_system_manifests]
  for_each = { for k, v in local.system_apps : k => v if v.app_role == "core" }

  name = each.key
  namespace = each.value.namespace
  repository = each.value.chart_repo
  chart = each.value.chart_name
  version = each.value.chart_version
  values = [
    file("./system/helm/${each.key}-values.yaml")
  ]
}
resource "kubectl_manifest" "core_post_install" {
  depends_on = [data.talos_cluster_health.this, helm_release.install_core_system_apps]
  for_each = local.post_install_manifests_by_role["core"]
  yaml_body = templatefile("./system/templates/${each.value.template_file}", { vars = each.value.vars })
}


# ---- Install ingress system apps -----
resource "helm_release" "install_ingress_system_apps" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.core_post_install]
  for_each = { for k, v in local.system_apps : k => v if v.app_role == "ingress" }

  name = each.key
  namespace = each.value.namespace
  repository = each.value.chart_repo
  chart = each.value.chart_name
  version = each.value.chart_version
  values = [
    file("./system/helm/${each.key}-values.yaml")
  ]
}
resource "kubectl_manifest" "ingress_post_install" {
  depends_on = [data.talos_cluster_health.this, helm_release.install_ingress_system_apps]
  for_each = local.post_install_manifests_by_role["ingress"]
  yaml_body = templatefile("./system/templates/${each.value.template_file}", { vars = each.value.vars })
}


# ---- Install storage system apps -----
resource "helm_release" "install_storage_system_apps" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.ingress_post_install]
  for_each = { for k, v in local.system_apps : k => v if v.app_role == "storage" }

  name = each.key
  namespace = each.value.namespace
  repository = each.value.chart_repo
  chart = each.value.chart_name
  version = each.value.chart_version
  values = [
    file("./system/helm/${each.key}-values.yaml")
  ]
}
resource "kubectl_manifest" "storage_post_install" {
  depends_on = [data.talos_cluster_health.this, helm_release.install_storage_system_apps]
  for_each = local.post_install_manifests_by_role["storage"]
  yaml_body = templatefile("./system/templates/${each.value.template_file}", { vars = each.value.vars })
}


# Create and init a database for any database dependent applications
resource "helm_release" "cnpg-clusters" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.storage_post_install]
  for_each = { for k, v in local.system_apps : k => v if can(v["db"]) }

  name = "${each.key}-cnpg-cluster"
  namespace = each.value.namespace
  repository = "https://cloudnative-pg.github.io/charts"
  chart = "cluster"
  version = "0.3.1"
  values = [
    file("./system/helm/cnpg-cluster-values.yaml")
  ]
  set = [
    {
      name = "cluster.initdb.database"
      value = each.key
    },
    {
      name = "cluster.instances"
      value = each.value.db.instances
    },
    {
      name = "cluster.storage.size"
      value = each.value.db.size
    },
    {
      name = "cluster.walStorage.size"
      value = each.value.db.wal
    },
  ]
}


# ---- Install service system apps -----
resource "helm_release" "install_service_system_apps" {
  depends_on = [data.talos_cluster_health.this, helm_release.cnpg-clusters]
  for_each = { for k, v in local.system_apps : k => v if v.app_role == "service" }

  name = each.key
  namespace = each.value.namespace
  repository = each.value.chart_repo
  chart = each.value.chart_name
  version = each.value.chart_version
  values = [
    file("./system/helm/${each.key}-values.yaml")
  ]
}
resource "kubectl_manifest" "services_post_install" {
  depends_on = [data.talos_cluster_health.this, helm_release.install_service_system_apps]
  for_each = local.post_install_manifests_by_role["storage"]
  yaml_body = templatefile("./system/templates/${each.value.template_file}", { vars = each.value.vars })
}
