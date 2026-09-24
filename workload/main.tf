locals {
  context = {
    base_public_domain  = module.akv.secrets["${var.environment}-base-public-domain"]
    base_private_domain = module.akv.secrets["${var.environment}-base-private-domain"]
    gateways = {
      public  = { ip = cidrhost(module.akv.secrets["${var.environment}-network"].lb_ip_pool, 0), name = "public" }
      private = { ip = cidrhost(module.akv.secrets["${var.environment}-network"].lb_ip_pool, 1), name = "private" }
    }
    # system = var.system
  }

  app_configs = {
    for k, v in var.apps : k => {
      namespace = v.namespace != null ? v.namespace : k

      chart = v.chart != null ? merge({
        name    = k
        version = "latest"
      }, v.chart) : null

      route = merge({
        dns_labels     = [k]
        https_redirect = true
        public         = false
        svc_name       = k
        svc_port       = 80
      }, v.route)

      keycloak = v.keycloak != null ? merge(var.system.keycloak.app_defaults, v.keycloak) : null
      postgres = v.postgres != null ? merge(var.system.cnpg.app_defaults, v.postgres) : null
      valkey   = v.valkey != null ? merge(var.system.valkey.app_defaults, v.valkey) : null
    }
  }
}

module "akv" {
  source         = "../modules/akv"
  name           = var.az_key_vault_name
  resource_group = var.az_key_vault_rg
}

module "cert_manager" {
  source             = "./modules/system/cert-manager"
  tag                = var.system.cert_manager.chart_tag
  environment        = var.environment
  base_public_domain = module.akv.secrets["${var.environment}-base-public-domain"]
  acme_email         = module.akv.secrets.acme-email
  cloudflare_token   = module.akv.secrets.cloudflare-token
}

module "metallb" {
  source  = "./modules/system/metallb"
  tag     = var.system.metallb.chart_tag
  ip_pool = module.akv.secrets["${var.environment}-network"].lb_ip_pool
}

module "istio" {
  depends_on = [module.metallb]
  source     = "./modules/system/istio"
  tag        = var.system.istio.chart_tag
  gateways = local.context.gateways
}

module "csi-nfs" {
  source = "./modules/system/csi-nfs"
  tag    = var.system.csi_nfs.chart_tag
}

module "mayastor" {
  depends_on     = [module.csi-nfs]
  source         = "./modules/system/mayastor"
  tag            = var.system.mayastor.chart_tag
  nfs_storage_gb = 200
  diskpool_nodes = nonsensitive([
    for k, v in module.akv.secrets["${var.environment}-nodes"] :
      k if v.role == "worker" && v.data_disk_gb != null
  ])
}

module "cnpg_operator" {
  depends_on = [module.mayastor]
  source     = "./modules/system/cnpg-operator"
  image_tag  = var.system.cnpg_operator.image_tag
  chart_tag  = var.system.cnpg_operator.chart_tag
  pg_images  = var.system.cnpg_operator.pg_images
}

module "valkey_operator" {
  depends_on = [module.mayastor]
  source     = "./modules/system/valkey-operator"
  tag        = var.system.valkey.operator.chart_tag
}

module "app_namespaces" {
  source   = "./modules/system/namespace"
  for_each = toset(distinct(concat([for k, v in var.apps : try(v.namespace, k)], ["keycloak"])))
  name     = each.key
}

# module "keycloak_app" {
#   depends_on = [module.cnpg_operator, module.valkey_operator, module.mayastor, module.cert_manager, module.app_namespaces]
#   source     = "./modules/app"
#   context    = local.context
#   name   = "keycloak"
#   config = {
#     namespace = "keycloak"
#     template_vars = {
#       image_tag = var.system.keycloak.image_tag
#       replicas = 1
#     }
#     route = {
#       dns_labels = ["auth"]
#       public = true
#       https_redirect = true
#       svc_name = "keycloak"
#       svc_port = 8080
#     }
#     postgres = {
#       base_gb = 20
#       wal_gb = 10
#       replicas = 1
#     }
#   }
# }

# resource "keycloak_realm" "this" {
#   depends_on   = [module.keycloak_app]
#   realm        = "${module.akv.secrets.keycloak-realm-prefix}-${var.environment}"
#   display_name = var.environment == "prod" ? title(module.akv.secrets.keycloak-realm-prefix) : "${title(module.akv.secrets.keycloak-realm-prefix)} ${upper(var.environment)}"
# }
#
# resource "keycloak_oidc_identity_provider" "microsoft_entra_idp" {
#   realm        = keycloak_realm.this.id
#   alias        = "entra" # https://<KEYCLOAK_HOSTNAME>/realms/<REALM>/broker/entra/endpoint
#   display_name = "Microsoft Entra"
#
#   client_id     = module.akv.secrets.entra-app.client_id
#   client_secret = module.akv.secrets.entra-app.client_secret
#
#   issuer            = "https://login.microsoftonline.com/${module.akv.secrets.entra-app.tenant_id}/v2.0"
#   authorization_url = "https://login.microsoftonline.com/${module.akv.secrets.entra-app.tenant_id}/oauth2/v2.0/authorize"
#   token_url         = "https://login.microsoftonline.com/${module.akv.secrets.entra-app.tenant_id}/oauth2/v2.0/token"
#   logout_url        = "https://login.microsoftonline.com/${module.akv.secrets.entra-app.tenant_id}/oauth2/v2.0/logout"
#   jwks_url          = "https://login.microsoftonline.com/${module.akv.secrets.entra-app.tenant_id}/discovery/v2.0/keys"
#   user_info_url     = "https://graph.microsoft.com/oidc/userinfo"
#   default_scopes    = "openid offline_access"
#
#   sync_mode          = "IMPORT"
#   trust_email        = true
#   validate_signature = true
# }

# module "apps" {
#   depends_on = [module.keycloak_app]
#   for_each   = local.app_configs
#   source     = "./modules/app"
#   context    = local.context
#   name   = each.key
#   config = each.value
# }
