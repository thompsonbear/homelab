module "akv" {
  source         = "../modules/akv"
  name           = var.az_key_vault_name
  resource_group = var.az_key_vault_rg
}

module "cert_manager" {
  source             = "./modules/core/cert-manager"
  tag                = var.system.cert_manager_tag
  environment        = "non-prod" # var.environment
  base_public_domain = module.akv.secrets.base-public-domain
  acme_email         = module.akv.secrets.acme-email
  cloudflare_token   = module.akv.secrets.cloudflare-token
}

module "metallb" {
  source  = "./modules/core/metallb"
  tag     = var.system.metallb_tag
  ip_pool = module.akv.secrets["${var.environment}-network"].lb_ip_pool
}

module "istio" {
  depends_on = [module.metallb]
  source     = "./modules/core/istio"
  tag        = var.system.istio_tag
  ip_pool    = module.akv.secrets["${var.environment}-network"].lb_ip_pool
}

module "mayastor" {
  source = "./modules/core/mayastor"
  tag    = var.system.mayastor_tag
}

module "cnpg_operator" {
  source    = "./modules/core/cnpg-operator"
  image_tag = var.system.cnpg.image_tag
  chart_tag = var.system.cnpg.chart_tag
  pg_images = [{
    major = 15
    image = "ghcr.io/cloudnative-pg/postgresql:15.19-202608170814-minimal-trixie@sha256:67b23fdf6dbf3d5bc5dc42cdbc5d292375582b1fe378c1dc69eb51c6fbc57730"
    }, {
    major = 16
    image = "ghcr.io/cloudnative-pg/postgresql:16.15-202608170814-minimal-trixie@sha256:e3041d59a94c072fa2fd4436b82ecdf34afc9d38c8cf2b836b009b09a1744c63"
    }, {
    major = 17
    image = "ghcr.io/cloudnative-pg/postgresql:17.11-202608170816-minimal-trixie@sha256:445ead3fd811466950a002b682a97c2a4907078b46fae8796b6637a763266a07"
    }, {
    major = 18
    image = "ghcr.io/cloudnative-pg/postgresql:18.6-202608170814-minimal-trixie@sha256:eb7979e4bd7fccaec0369b550b9649eec1f014de04621fac6e653244e75cca46"
  }]
}

module "keycloak" {
  depends_on         = [module.cnpg_operator, module.mayastor, module.istio, module.cert_manager]
  source             = "./modules/core/keycloak"
  tag                = var.system.keycloak_tag
  base_public_domain = module.akv.secrets["${var.environment}-base-public-domain"]
}

module "app_namespaces" {
  source   = "./modules/core/namespace"
  for_each = toset(distinct([for k, v in var.apps : try(v.namespace, k)]))
  name     = each.key
}

# module "apps" {
#   depends_on = [module.keycloak, module.app_namespaces]
#   source     = "./modules/app"
#   for_each   = var.apps
#
#   app_name = each.key
#
#   namespace = try(each.value.namespace, each.key)
#
#   image_version = each.value.image_version
#
#   chart = {
#     name    = try(each.value.chart.name, each.key)
#     repo    = each.value.chart.repo
#     version = try(each.value.chart.version, each.value.version)
#   }
#
#   dns = can(each.value.dns) ? {
#     labels = try(each.value.dns.labels, [each.key])
#     public = try(each.value.dns.public, false)
#     } : {
#     labels = [each.key]
#     public = false
#   }
#
#   backend = can(each.value.backend) ? {
#     service = try(each.value.backend.service, each.key)
#     port    = try(each.value.backend.port, 80)
#     } : {
#     service = each.key
#     port    = 80
#   }
#
#   keycloak = can(each.value.keycloak) ? each.value.keycloak : null
#   postgres = can(each.value.postgres) ? each.value.postgres : null
#   valkey   = can(each.value.valkey) ? each.value.valkey : null
# }
