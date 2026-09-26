locals {
  context = {
    base_public_domain  = module.akv.secrets["${var.environment}-base-public-domain"]
    base_private_domain = module.akv.secrets["${var.environment}-base-private-domain"]
    gateways = {
      public  = { ip = cidrhost(module.akv.secrets["${var.environment}-network"].lb_ip_pool, 0), name = "public" }
      private = { ip = cidrhost(module.akv.secrets["${var.environment}-network"].lb_ip_pool, 1), name = "private" }
    }
  }

  app_configs = {
    for k, v in local.apps : k => {
      namespace = can(v.namespace) ? v.namespace : k


      chart = can(v.chart) ? merge({
        name    = k
        version = "latest"
      }, v.chart) : null

      route = merge({
        dns_labels     = [k]
        https_redirect = true
        public         = false
        svc_name       = k
        svc_port       = 80
      }, can(v.route) ? v.route : {})

      keycloak = can(v.keycloak) ? merge(local.app_defaults.keycloak, v.keycloak) : null
      postgres = can(v.postgres) ? merge(local.app_defaults.postgres, v.postgres) : null
      valkey   = can(v.valkey) ? merge(local.app_defaults.valkey, { chart_tag = local.system.valkey.chart_tag }, v.valkey) : null
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
  tag                = local.system.cert_manager.chart_tag
  environment        = "dev" # var.environment
  base_public_domain = module.akv.secrets["${var.environment}-base-public-domain"]
  acme_email         = module.akv.secrets.acme-email
  cloudflare_token   = module.akv.secrets.cloudflare-token
}

module "metallb" {
  source  = "./modules/system/metallb"
  tag     = local.system.metallb.chart_tag
  ip_pool = module.akv.secrets["${var.environment}-network"].lb_ip_pool
}

module "istio" {
  depends_on = [module.metallb]
  source     = "./modules/system/istio"
  tag        = local.system.istio.chart_tag
  gateways = local.context.gateways
}

module "csi-nfs" {
  source = "./modules/system/csi-nfs"
  tag    = local.system.csi_nfs.chart_tag
}

module "mayastor" {
  depends_on     = [module.csi-nfs]
  source         = "./modules/system/mayastor"
  tag            = local.system.mayastor.chart_tag
  nfs_storage_gb = 200
  diskpool_nodes = nonsensitive([
    for k, v in module.akv.secrets["${var.environment}-nodes"] :
      k if v.role == "worker" && v.data_disk_gb != null
  ])
}

module "cnpg_operator" {
  depends_on = [module.mayastor]
  source     = "./modules/system/cnpg-operator"
  image_tag  = local.system.cnpg.operator.image_tag
  chart_tag  = local.system.cnpg.operator.chart_tag
  pg_images  = local.system.cnpg.operator.pg_images
}

module "valkey_operator" {
  depends_on = [module.mayastor]
  source     = "./modules/system/valkey-operator"
  tag        = local.system.valkey.operator.chart_tag
}

module "app_namespaces" {
  source   = "./modules/system/namespace"
  for_each = toset(distinct(concat([for k, v in local.apps : try(v.namespace, k)], ["keycloak"])))
  name     = each.key
}

module "keycloak_app" {
  depends_on = [module.cnpg_operator, module.valkey_operator, module.mayastor, module.cert_manager, module.app_namespaces]
  source     = "./modules/app"
  context    = local.context
  name   = "keycloak"
  config = {
    namespace = "keycloak"
    template_vars = {
      image_tag = local.system.keycloak.image_tag
      replicas = 1
    }
    route = {
      dns_labels = ["auth"]
      public = true
      https_redirect = true
      svc_name = "keycloak"
      svc_port = 8080
    }
    postgres = {
      version = 18
      base_gb = 20
      wal_gb = 10
      instances = 1
      encoding = "UTF8"
      extensions = []
      sql = []
    }
  }
}

resource "time_sleep" "wait_for_keycloak" {
  depends_on      = [module.keycloak_app]
  create_duration = "120s"
}

# resource "keycloak_realm" "this" {
#   depends_on   = [time_sleep.wait_for_keycloak]
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
