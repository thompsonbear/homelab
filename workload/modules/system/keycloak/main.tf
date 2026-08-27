module "namespace" {
  source     = "../namespace"
  name       = "keycloak"
  privileged = false
}

module "app" {
  source               = "../../app"
  app_name             = "keycloak"
  namespace            = module.namespace.name
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
