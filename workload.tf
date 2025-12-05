# Generate a random admin password for breakglass management/deployment
resource "random_password" "admin_password" {
  length  = 32
  special = true
}

# Create privileged namespaces for all charts
resource "kubectl_manifest" "create_namespaces" {
  depends_on = [data.talos_cluster_health.this]
  for_each   = merge(local.workload.core, local.workload.ingress, local.workload.storage, local.workload.idp, local.workload.app)

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
  depends_on = [kubectl_manifest.create_namespaces, kubectl_manifest.pre_apply_crds]
  for_each   = local.pre_install_manifests

  yaml_body = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}

# ---- Install core workloads -----
resource "helm_release" "core_charts" {
  depends_on = [kubectl_manifest.pre_apply_manifests]
  for_each   = local.workload.core

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
  depends_on = [helm_release.core_charts]
  for_each   = local.core_manifests
  yaml_body  = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}


# ---- Install ingress workloads -----
resource "helm_release" "ingress_charts" {
  depends_on = [kubectl_manifest.core_manifests]
  for_each   = local.workload.ingress

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
  depends_on = [helm_release.ingress_charts]
  for_each   = local.ingress_manifests
  yaml_body  = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}


# ---- Install storage workloads -----
resource "helm_release" "storage_charts" {
  depends_on = [kubectl_manifest.ingress_manifests]
  for_each   = local.workload.storage

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
  depends_on = [helm_release.storage_charts]
  for_each   = local.storage_manifests
  yaml_body  = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}

# ---- workload-data.tf - init db/kv clusters -----

# ---- Install idp workloads -----
resource "helm_release" "idp_charts" {
  depends_on = [time_sleep.wait_120s_for_db_init, helm_release.kv_clusters]
  for_each   = local.workload.idp

  name       = each.key
  namespace  = each.value.namespace
  repository = each.value.chart_repo
  chart      = each.value.chart_name
  version    = each.value.chart_version
  set        = try(each.value.set, [])
  values = [
    file("./helm/${each.key}-values.yaml")
  ]
}
resource "kubectl_manifest" "idp_manifests" {
  depends_on = [helm_release.idp_charts]
  for_each   = local.idp_manifests
  yaml_body  = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}

# ---- workload-idp.tf - create idp oauth clients/proxies

# ---- Install app workloads -----
resource "helm_release" "app_charts" {
  depends_on = [time_sleep.wait_120s_for_db_init, helm_release.kv_clusters]
  for_each   = local.workload.app

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
  for_each   = local.app_manifests
  yaml_body  = templatefile("./templates/${each.value.template_file}", { vars = each.value.vars })
}

