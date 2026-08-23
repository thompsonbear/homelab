resource "helm_release" "cnpg_cluster" {
  name       = "${var.app_name}-db"
  chart      = "cluster"
  repository = "https://cloudnative-pg.github.io/charts"
  namespace  = var.namespace
  version    = var.tag

  values = [templatefile("${path.module}/resources/values.tftpl", {
    pg_version = var.pg_version
    replicas   = var.replicas
    data_gb    = var.data_gb
    wal_gb     = var.wal_gb
    initdb = {
      name     = var.db.name
      encoding = var.db.encoding
      sql      = var.db.sql
    }
  })]
}

resource "time_sleep" "wait_for_cnpg" {
  depends_on = [helm_release.cnpg_cluster]
  create_duration = "60s"
}
