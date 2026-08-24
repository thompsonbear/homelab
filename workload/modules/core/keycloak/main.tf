module "namespace" {
  source     = "../namespace"
  name       = "keycloak"
  privileged = false
}

module "app" {
  source        = "../../app"
  app_name      = "keycloak"
  namespace     = module.namespace.name
  image_version = var.tag
  manifests_dir = "${path.module}/resources/manifests"
  dns = {
    labels = ["auth"]
    public = true
  }
  backend = {
    service = "keycloak"
  }
  postgres = {}
}
