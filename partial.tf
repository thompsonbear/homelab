      = "jgroups-fd"
            container_port = "57800"
          }
          startup_probe {
            http_get {
              path = "/health/started"
              port = 9000
            }
            period_seconds    = 1
            failure_threshold = 600
          }
          readiness_probe {
            http_get {
              path = "/health/ready"
              port = 9000
            }
            period_seconds    = 10
            failure_threshold = 3
          }
          liveness_probe {
            http_get {
              path = "/health/live"
              port = 9000
            }
            period_seconds    = 10
            failure_threshold = 3
          }
          env {
            name  = "KC_BOOTSTRAP_ADMIN_USERNAME"
            value = var.admin_username
          }
          env {
            name = "KC_BOOTSTRAP_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = "kcadmin-secret"
                key  = "password"
              }
            }
          }
          env {
            name  = "KC_HTTP_ENABLED"
            value = "true"
          }
          env {
            name  = "KC_PROXY_HEADERS"
            value = "xforwarded"
          }
          env {
            name  = "KC_HOSTNAME_STRICT"
            value = "false"
          }
          env {
            name  = "KC_HEALTH_ENABLED"
            value = "true"
          }
          env {
            name  = "KC_DB_URL_DATABASE"
            value = "keycloak"
          }
          env {
            name  = "KC_DB_URL"
            value = "jdbc:postgresql://keycloak-cnpg-cluster-rw/keycloak"
          }
          env {
            name  = "KC_DB"
            value = "postgres"
          }
          env {
            name = "KC_DB_USERNAME"
            value_from {
              secret_key_ref {
                name = "keycloak-cnpg-cluster-app"
                key  = "username"
              }
            }
          }
          env {
            name = "KC_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "keycloak-cnpg-cluster-app"
                key  = "password"
              }
            }
          }
        }
      }
    }
  }
}

resource "keycloak_realm" "this" {
  depends_on   = [kubernetes_stateful_set_v1.keycloak_sts]
  realm        = var.realm_name
  display_name = title(var.realm_name)
}

resource "keycloak_openid_client_scope" "app_roles_scope" {
  realm_id = keycloak_realm.this.id
  name     = "app-roles"
}

# Connect external idp - Entra
resource "keycloak_oidc_identity_provider" "microsoft_entra_idp" {
  realm        = keycloak_realm.this.id
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
TerraformjPVe#XI /home/tb/repos/homelab/workload/modules/operations/keycloak/main.tf

