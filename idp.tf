ephemeral "random_password" "oauth_client_secrets" {
  for_each         = local.oauth_workloads
  length           = 32
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

ephemeral "random_password" "oauth_cookie_secrets" {
  for_each         = local.oauth_proxy_workloads
  length           = 32
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create a bear realm, leaving the default master realm for administration only
resource "keycloak_realm" "bear" {
  depends_on   = [kubectl_manifest.idp_manifests]
  realm        = "bear"
  display_name = "Bear Home"
}

# Create an oauth2 client for each oauth workload
resource "keycloak_openid_client" "workload_clients" {
  for_each = local.oauth_workloads

  realm_id                 = keycloak_realm.bear.id
  client_id                = "${each.key}-client"
  client_secret_wo         = ephemeral.random_password.oauth_client_secrets[each.key].result
  client_secret_wo_version = 1

  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris   = each.value.oauth.proxy ? ["https://${each.value.oauth.fqdn}/oauth2/callback"] : try(each.value.oauth.redirect_uris, [])
}

# Create a global admin role for administration
resource "keycloak_role" "bear_admin_realm_role" {
  realm_id    = keycloak_realm.bear.id
  name        = "bear-admin"
  description = "Bear Realm Admin"
}

# Create an admin role for each client
resource "keycloak_role" "workload_client_roles" {
  for_each  = local.oauth_workloads
  realm_id  = keycloak_realm.bear.id
  client_id = keycloak_openid_client.workload_clients[each.key].id
  name      = "${each.key}-admin"
}

# Connect external idp - Entra
resource "keycloak_oidc_identity_provider" "microsoft_entra_idp" {
  realm = keycloak_realm.bear.id
  alias = "entra" # https://<KEYCLOAK_HOSTNAME>/realms/<REALM>/broker/entra/endpoint
  display_name = "Microsoft Entra"

  client_id = var.entra_client_id
  client_secret = var.entra_client_secret
 
  issuer = "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0"
  authorization_url = "https://login.microsoftonline.com/${var.entra_tenant_id}/oauth2/v2.0/authorize"
  token_url = "https://login.microsoftonline.com/${var.entra_tenant_id}/oauth2/v2.0/token"
  logout_url = "https://login.microsoftonline.com/${var.entra_tenant_id}/oauth2/v2.0/logout"
  jwks_url = "https://login.microsoftonline.com/${var.entra_tenant_id}/discovery/v2.0/keys"
  user_info_url = "https://graph.microsoft.com/oidc/userinfo"
  default_scopes = "openid offline_access"

  sync_mode = "FORCE"
  trust_email = true
  validate_signature = true
}

# Create a forward auth middleware to internally forward requests to the oauth proxy auth endpoint
# Response is either 401-403 (Unauthenticated/Unauthorized) or 202 (Authorized)
resource "kubectl_manifest" "oauth2_proxy_forwardauth_middlewares" {
  depends_on = [kubectl_manifest.ingress_manifests]
  for_each   = local.oauth_proxy_workloads

  yaml_body = templatefile("./templates/traefik-forward-auth-middleware.yaml.tmpl", {
    name            = "oauth2-proxy-forwardauth"
    namespace       = each.value.namespace
    forward_address = "http://${each.key}-oauth2-proxy.${each.value.namespace}/oauth2/auth"
  })
}

# Create an errors middleware to redirect the user to the login page if a 401/403 is recieved
resource "kubectl_manifest" "oauth2_proxy_errors_middlewares" {
  depends_on = [kubectl_manifest.ingress_manifests]
  for_each   = local.oauth_proxy_workloads

  yaml_body = templatefile("./templates/traefik-errors-middleware.yaml.tmpl", {
    name      = "oauth2-proxy-errors"
    namespace = each.value.namespace
    key       = each.key
  })
}

# Preset the oauth2-proxy configmaps
resource "kubectl_manifest" "oauth2_proxy_configs" {
  for_each = local.oauth_proxy_workloads

  yaml_body = templatefile("./templates/oauth2-proxy-config.yaml.tmpl", {
    name          = "${each.key}-oauth2-proxy"
    namespace     = each.value.namespace
    redirect_url  = "https://${each.value.oauth.fqdn}/oauth2/callback"
    allowed_roles = "[\"bear-admin\", \"${each.key}-client:${each.key}-admin\"]"
    insecure      = var.insecure
  })
}

# Deploy oauth2-proxy for each proxied oauth workload
resource "helm_release" "oauth2_proxies" {
  depends_on = [keycloak_openid_client.workload_clients]
  for_each   = local.oauth_proxy_workloads

  name       = "${each.key}-oauth2-proxy"
  namespace  = each.value.namespace
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "9.0.0"
  values = [
    file("./helm/oauth2-proxy-values.yaml")
  ]

  set_wo_revision = 1
  set_wo = [{
    name  = "config.clientID"
    value = "${each.key}-client"
    }, {
    name  = "config.clientSecret"
    value = ephemeral.random_password.oauth_client_secrets[each.key].result
    }, {
    name  = "config.cookieSecret"
    value = ephemeral.random_password.oauth_cookie_secrets[each.key].result
    }, {
    name  = "config.cookieName"
    value = "${each.key}-oauth2-proxy"
    }, {
    name  = "config.existingConfig"
    value = "${each.key}-oauth2-proxy"
    }, {
    name  = "ingress.hosts[0]"
    value = each.value.oauth.fqdn
    }, {
    name  = "ingress.tls[0].secretName"
    value = "${each.key}-tls"
    }, {
    name  = "ingress.tls[0].hosts[0]"
    value = each.value.oauth.fqdn
  }]
}


