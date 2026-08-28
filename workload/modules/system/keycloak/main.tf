module "namespace" {
  source     = "../namespace"
  name       = "keycloak"
  privileged = false
}

resource "kubernetes_secret_v1" "keycloak_admin_secret" {
  metadata {
    name      = "keycloak-admin-secret"
    namespace = module.namespace.name
  }
  data = {
    "username" = var.keycloak_admin.username
    "password" = var.keycloak_admin.password
  }
  type = "kubernetes.io/basic-auth"
}

module "app" {
  depends_on = [ kubernetes_secret_v1.keycloak_admin_secret ]
  source               = "../../app"
  app_name             = "keycloak"
  namespace            = module.namespace.name
  replicas             = var.replicas
  image_tag            = var.tag
  base_public_domain   = var.base_public_domain
  gateways             = var.gateways
  custom_manifests_dir = "${path.module}/resources/manifests"
  dns = {
    labels = ["auth"]
    public = true
  }
  backend = {
    service = "keycloak"
  }
  postgres = {}
}
