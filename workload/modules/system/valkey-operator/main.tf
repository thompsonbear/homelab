module "namespace" {
  source     = "../namespace"
  name       = "valkey-system"
  privileged = true
}

resource "helm_release" "valkey-operator" {
  name       = "valkey-operator"
  chart      = "valkey-operator"
  repository = "https://valkey.io/valkey-helm/"
  namespace  = module.namespace.name
  version    = var.tag
  set = [{
    name  = "replicaCount"
    value = var.replicas
  }]
}
