module "namespace" {
  source     = "../namespace"
  name       = "csi-nfs"
  privileged = true
}

resource "helm_release" "csi-nfs" {
  name       = "csi-nfs"
  chart      = "csi-driver-nfs"
  repository = "https://kubernetes-csi.github.io/csi-driver-nfs"
  namespace  = module.namespace.name
  version    = var.tag
}
