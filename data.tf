# Create and init a database for any database dependent apps
resource "helm_release" "cnpg_clusters" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.storage_manifests]
  for_each   = local.db_apps

  name       = "${each.key}-cnpg-cluster"
  namespace  = each.value.namespace
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cluster"
  version    = "0.3.1"
  values = [
    file("./helm/cnpg-cluster-values.yaml")
  ]
  set = [
    {
      name  = "cluster.initdb.database"
      value = each.key
    },
    {
      name  = "cluster.initdb.owner"
      value = each.key
    },
    {
      name  = "cluster.roles[0].name"
      value = each.key
    },
    {
      name  = "cluster.roles[0].createddb"
      value = true
    },
    {
      name  = "cluster.roles[0].login"
      value = true
    },
    {
      name  = "cluster.roles[0].superuser"
      value = true
    },
    {
      name  = "cluster.instances"
      value = each.value.db.instances
    },
    {
      name  = "cluster.storage.size"
      value = each.value.db.size
    },
    {
      name  = "cluster.walStorage.size"
      value = each.value.db.wal
    }
  ]
}

resource "time_sleep" "wait_120s_for_db_init" {
  depends_on = [helm_release.cnpg_clusters]

  create_duration = "120s"
}

# Create and init a kv store for any kv dependent apps
resource "helm_release" "kv_clusters" {
  depends_on = [kubectl_manifest.storage_manifests]
  for_each   = local.kv_apps

  name       = "${each.key}-kv-cluster"
  namespace  = each.value.namespace
  repository = "oci://registry-1.docker.io/cloudpirates"
  chart      = "valkey"
  version    = "0.10.2"
  values = [
    file("./helm/valkey-values.yaml")
  ]
  set = [
    {
      name  = "architecture"
      value = each.value.kv.instances > 1 ? "replication" : "standalone"
    },
    {
      name  = "sentinel.enabled"
      value = each.value.kv.instances > 1 ? true : false
    },
    {
      name  = "replicaCount"
      value = each.value.kv.instances
    },
    {
      name  = "persistance.size"
      value = each.value.kv.size
    }
  ]
}

