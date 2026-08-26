module "namespace" {
  source     = "../namespace"
  name       = "cnpg"
  privileged = true
}

resource "helm_release" "cnpg-operator" {
  name       = "cnpg-operator"
  chart      = "cloudnative-pg"
  repository = "https://cloudnative-pg.github.io/charts"
  namespace  = module.namespace.name
  version    = var.chart_tag
  set = [{
    name  = "replicaCount"
    value = var.replicas
    }, {
    name  = "image.tag"
    value = var.image_tag
  }]
}

resource "kubectl_manifest" "pg_global_image_catalog" {
  depends_on = [helm_release.cnpg-operator]
  yaml_body = yamlencode({
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "ClusterImageCatalog"
    metadata = {
      name = "postgresql-global"
    }
    spec = {
      images = var.pg_images
    }
  })
}
