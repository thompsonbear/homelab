locals {
  istio_repo = "https://istio-release.storage.googleapis.com/charts"
  gateway_api_crds = {
    for manifest in provider::kubernetes::manifest_decode_multi(file("${path.module}/resources/gateway-api-crds.yaml")) :
    manifest.metadata.name => { for key, value in manifest : key => value if key != "status" }
  }
  gateways = {
    public  = { ip = cidrhost(var.ip_pool, 0) }
    private = { ip = cidrhost(var.ip_pool, 1) }
  }
}

resource "kubernetes_manifest" "gateway_api_crds" {
  for_each = local.gateway_api_crds
  manifest = each.value
}

module "namespace" {
  source     = "../namespace"
  name       = "istio-system"
  privileged = true
}

resource "helm_release" "base" {
  depends_on = [kubernetes_manifest.gateway_api_crds]
  name       = "base"
  chart      = "base"
  repository = local.istio_repo
  namespace  = module.namespace.name
  version    = var.tag
}

resource "helm_release" "istiod" {
  depends_on = [helm_release.base]
  name       = "istiod"
  chart      = "istiod"
  repository = local.istio_repo
  namespace  = module.namespace.name
  version    = var.tag
  set = [
    { name = "profile", value = "ambient" },
  ]
}

resource "helm_release" "cni" {
  depends_on = [helm_release.istiod]
  name       = "cni"
  chart      = "cni"
  repository = local.istio_repo
  namespace  = module.namespace.name
  version    = var.tag
  set = [
    { name = "profile", value = "ambient" },
  ]
}

resource "helm_release" "ztunnel" {
  depends_on = [helm_release.cni]
  name       = "ztunnel"
  chart      = "ztunnel"
  repository = local.istio_repo
  namespace  = module.namespace.name
  version    = var.tag
}

resource "kubectl_manifest" "gateways" {
  depends_on = [helm_release.ztunnel]
  for_each   = local.gateways
  manifest = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = each.key
      namespace = module.namespace.name
    }
    spec = {
      gatewayClassName = "istio"
      allowedListeners = [{
        namespaces = {
          from = "All"
        }
      }]
      addresses = [{
        type  = "IPAddress"
        value = each.value.ip
      }]
    }
  })
}
