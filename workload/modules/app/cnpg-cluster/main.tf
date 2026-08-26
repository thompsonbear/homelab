resource "helm_release" "cnpg_cluster" {
  name       = "${var.app_name}-cnpg"
  chart      = "cluster"
  repository = "https://cloudnative-pg.github.io/charts"
  namespace  = var.namespace
  version    = var.cnpg_cluster_chart_tag

  values = [templatefile("${path.module}/resources/values.tftpl", {
    pg_major_version = var.pg_major_version
    replicas         = var.replicas
    base_gb          = var.base_gb
    wal_gb           = var.wal_gb
    initdb = {
      name     = var.db.name
      encoding = var.db.encoding
      sql      = var.db.sql
    }
  })]
}

resource "time_sleep" "wait_for_cnpg" {
  depends_on      = [helm_release.cnpg_cluster]
  create_duration = "60s"
}
