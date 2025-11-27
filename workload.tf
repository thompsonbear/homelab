# Create privileged namespaces for all charts
resource "kubectl_manifest" "create_namespaces" {
  depends_on = [data.talos_cluster_health.this]
  for_each   = merge(local.workload.core.charts, local.workload.ingress.charts, local.workload.storage.charts, local.workload.app.charts)

  yaml_body = templatefile("./templates/privileged-namespace.yaml.tmpl", {
    namespace = each.value.namespace
    name      = "${each.key}-system"
  })
}

# Apply all crds located in ./crds
# Required for any custom resources to be applied by the pre_apply_system_manifests resource
resource "kubectl_manifest" "pre_apply_crds" {
  depends_on = [data.talos_cluster_health.this]
  for_each   = fileset("./crds/", "*.yaml")

  yaml_body = file("./crds/${each.value}")
}

# Apply manifests that are required before other resources are created
# If a custom resource is used, the crd must be added to ./crds
resource "kubectl_manifest" "pre_apply_manifests" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.create_namespaces, kubectl_manifest.pre_apply_crds]
  for_each   = local.workload.pre_install_manifests

  yaml_body = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}

# ---- Install core workloads -----
resource "helm_release" "core_charts" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.pre_apply_manifests]
  for_each   = local.workload.core.charts

  name       = each.key
  namespace  = each.value.namespace
  repository = each.value.chart_repo
  chart      = each.value.chart_name
  version    = each.value.chart_version
  values = [
    file("./helm/${each.key}-values.yaml")
  ]
}
resource "kubectl_manifest" "core_manifests" {
  depends_on = [data.talos_cluster_health.this, helm_release.core_charts]
  for_each   = try(local.workload.core.manifests, {})
  yaml_body  = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}


# ---- Install ingress workloads -----
resource "helm_release" "ingress_charts" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.core_manifests]
  for_each   = local.workload.ingress.charts

  name       = each.key
  namespace  = each.value.namespace
  repository = each.value.chart_repo
  chart      = each.value.chart_name
  version    = each.value.chart_version
  values = [
    file("./helm/${each.key}-values.yaml")
  ]
}
resource "kubectl_manifest" "ingress_manifests" {
  depends_on = [data.talos_cluster_health.this, helm_release.ingress_charts]
  for_each   = try(local.workload.ingress.manifests, {})
  yaml_body  = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}


# ---- Install storage workloads -----
resource "helm_release" "storage_charts" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.ingress_manifests]
  for_each   = local.workload.storage.charts

  name       = each.key
  namespace  = each.value.namespace
  repository = each.value.chart_repo
  chart      = each.value.chart_name
  version    = each.value.chart_version
  values = [
    file("./helm/${each.key}-values.yaml")
  ]
}
resource "kubectl_manifest" "storage_manifests" {
  depends_on = [data.talos_cluster_health.this, helm_release.storage_charts]
  for_each   = try(local.workload.storage.manifests, {})
  yaml_body  = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}


# Create and init a database for any database dependent apps
resource "helm_release" "cnpg-clusters" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.storage_manifests]
  for_each   = { for k, v in local.workload.app.charts : k => v if can(v["db"]) }

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
    },
  ]
}
resource "time_sleep" "wait_120s_for_db_init" {
  depends_on = [helm_release.cnpg-clusters]

  create_duration = "120s"
}


# ---- Install app workloads -----
resource "helm_release" "app_charts" {
  depends_on = [data.talos_cluster_health.this, time_sleep.wait_120s_for_db_init]
  for_each   = local.workload.app.charts

  name       = each.key
  namespace  = each.value.namespace
  repository = each.value.chart_repo
  chart      = each.value.chart_name
  version    = each.value.chart_version
  values = [
    file("./helm/${each.key}-values.yaml")
  ]
}
resource "kubectl_manifest" "app_manifests" {
  depends_on = [data.talos_cluster_health.this, helm_release.app_charts]
  for_each   = try(local.workload.app.manifests, {})
  yaml_body  = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}

