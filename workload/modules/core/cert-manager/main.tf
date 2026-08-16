module "namespace" {
  source = "../namespace"
  name = "cert-manager"
  privileged = true
}

resource "helm_release" "cert_manager" {
  name = "cert-manager"
  chart = "cert-manager"
  repository = "https://charts.jetstack.io"
  namespace = module.namespace.name
  version = var.tag
}
