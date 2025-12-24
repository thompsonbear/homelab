resource "random_password" "oauth_client_secrets" {
  for_each         = merge(local.oauth_proxy_workloads, local.oauth_workloads)
  length           = 32
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create a bear realm, leaving the default master realm for administration only
resource "keycloak_realm" "bear" {
  depends_on   = [helm_release.idp_charts]
  realm        = "bear"
  display_name = "Bear Home"
}

# Create an oauth2 client for each oauth workload
resource "keycloak_openid_client" "workload_clients" {
  for_each = merge(local.oauth_workloads, local.oauth_proxy_workloads)

  realm_id      = keycloak_realm.bear.id
  client_id     = each.key
  client_secret = try(each.value.oauth_config.client_secret, random_password.oauth_client_secrets[each.key].result)

  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris   = can(each.value.fqdn) ? ["https://${each.value.fqdn}/oauth2/callback"] : try(each.value.oauth_config.redirect_uris, [])
}

# Create a global admin role for administration
resource "keycloak_role" "bear_admin_realm_role" {
  realm_id    = keycloak_realm.bear.id
  name        = "bear-admin"
  description = "Bear Realm Admin"
}

# Create an admin role for each client
resource "keycloak_role" "workload_client_roles" {
  for_each  = merge(local.oauth_workloads, local.oauth_proxy_workloads)
  realm_id  = keycloak_realm.bear.id
  client_id = keycloak_openid_client.workload_clients[each.key].id
  name      = "admin"
}

# Connect external idp - Entra
resource "keycloak_oidc_identity_provider" "microsoft_entra_idp" {
  realm        = keycloak_realm.bear.id
  alias        = "entra" # https://<KEYCLOAK_HOSTNAME>/realms/<REALM>/broker/entra/endpoint
  display_name = "Microsoft Entra"

  client_id     = var.entra_client_id
  client_secret = var.entra_client_secret

  issuer            = "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0"
  authorization_url = "https://login.microsoftonline.com/${var.entra_tenant_id}/oauth2/v2.0/authorize"
  token_url         = "https://login.microsoftonline.com/${var.entra_tenant_id}/oauth2/v2.0/token"
  logout_url        = "https://login.microsoftonline.com/${var.entra_tenant_id}/oauth2/v2.0/logout"
  jwks_url          = "https://login.microsoftonline.com/${var.entra_tenant_id}/discovery/v2.0/keys"
  user_info_url     = "https://graph.microsoft.com/oidc/userinfo"
  default_scopes    = "openid offline_access"

  sync_mode          = "IMPORT"
  trust_email        = true
  validate_signature = true
}

