variable "db" {
  type = object({
    name = var.db.name
    host = "${var.app_name}-cnpg-cluster-rw.${var.namespace}.svc.cluster.local"
    port = 5432
    secret_name = "${var.app_name}-cnpg-cluster-app"
  })
}
