resource "kubectl_manifest" "cnpg_cluster" {
  yaml_body = yamlencode({
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = "postgres-${var.app_name}"
      namespace = var.namespace
    }
    spec = {
      instances = var.replicas
      imageCatalogRef = {
        apiGroup = "postgresql.cnpg.io"
        kind     = "ClusterImageCatalog"
        major    = var.pg_major_version
        name     = "postgresql-global"
      }
      bootstrap = {
        initdb = {
          database               = var.db.name
          encoding               = var.db.encoding
          postInitApplicationSQL = concat(var.db.sql, [for extension in var.db.extensions : "CREATE EXTENSION IF NOT EXISTS ${extension.name} CASCADE;" if extension.create])
        }
      }
      storage = {
        size         = "${var.base_gb}Gi"
        storageClass = "mayastor-1"
      }
      walStorage = {
        size         = "${var.wal_gb}Gi"
        storageClass = "mayastor-1"
      }
      managed = {
        roles = [{
          name = var.app_name
          superuser = true
          createdb = true
          login = true
        }]
      }
      postgresql = {
        extensions               = [for extension in var.db.extensions : { name = extension.name }]
        shared_preload_libraries = [for extension in var.db.extensions : extension.name if extension.preload]
      }
    }
  })
}

resource "time_sleep" "wait_for_cnpg" {
  depends_on      = [kubectl_manifest.cnpg_cluster]
  create_duration = "60s"
}
