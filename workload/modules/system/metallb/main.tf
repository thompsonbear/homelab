module "namespace" {
  source     = "../namespace"
  name       = "metallb"
  privileged = true
}

resource "helm_release" "metallb" {
  name       = "metallb"
  chart      = "metallb"
  repository = "https://metallb.github.io/metallb"
  namespace  = module.namespace.name
  version    = var.tag

  values = [templatefile("${path.module}/resources/values.tftpl", { tag = var.tag })]
}

resource "kubectl_manifest" "ipaddresspool" {
  depends_on = [helm_release.metallb]
  yaml_body = yamlencode({
    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "IPAddressPool"
    "metadata" = {
      "name"      = "ip-pool"
      "namespace" = module.namespace.name
    }
    "spec" = {
      "addresses" = [
        var.ip_pool
      ]
    }
  })
}

resource "kubectl_manifest" "l2advertisement" {
  depends_on = [helm_release.metallb]
  yaml_body = yamlencode({
    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "L2Advertisement"
    "metadata" = {
      "name"      = "l2advertisement"
      "namespace" = module.namespace.name
    }
    "spec" = {
      "ipAddressPools" = [
        "ip-pool"
      ]
      "interfaces" = [
        "eth0"
      ]
    }
  })
}
