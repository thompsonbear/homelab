resource "random_password" "client_secret" {
  length           = 32
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "kubernetes_secret_v1" "oauth_secret" {
  metadata {
    name = "${var.client_id}-oauth-secret"
    namespace = var.namespace
  }
  data = {
    client_id     = var.client_id
    client_secret = random_password.client_secret.result
  }
}

# Create an oauth2 client for each oauth workload
resource "keycloak_openid_client" "this" {
  realm_id      = var.realm_id
  client_id     = var.client_id
  client_secret = random_password.client_secret.result

  access_type                     = "CONFIDENTIAL"
  standard_flow_enabled           = true
  valid_redirect_uris             = var.redirect_uris
  valid_post_logout_redirect_uris = var.logout_uris
}

resource "keycloak_openid_client_scope" "app_roles" {
  realm_id = var.realm_id
  name     = "app-roles"
}

resource "keycloak_openid_client_default_scopes" "this" {
  realm_id       = var.realm_id
  client_id      = keycloak_openid_client.this.client.id
  default_scopes = ["profile", "email", "offline_access", keycloak_openid_client_scope.app_roles.name]
}

resource "keycloak_openid_user_client_role_protocol_mapper" "this" {
  realm_id                    = var.realm_id
  client_scope_id             = keycloak_openid_client_scope.app_roles.id
  name                        = "${var.client_id} client app roles"
  client_id_for_role_mappings = var.client_id
  client_role_prefix          = try(var.prefix_role_claim, true) ? "${each.key}:" : ""
  multivalued                 = var.multivalued_role_claim
  claim_name                  = var.multivalued_role_claim ? "roles" : "role"
}

# Create oauth workload roles for each client (a default admin role is always created)
resource "keycloak_role" "client_roles" {
  for_each  = toset(var.client_roles)
  realm_id  = var.realm_id
  client_id = keycloak_openid_client.this.id
  name      = each.value
}
