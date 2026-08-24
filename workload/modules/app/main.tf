locals {
  default_manifests_dir = "${path.root}/resources/${var.app_name}/manifests"

  manifests_dir = coalesce(
    var.manifests_dir,
    local.default_manifests_dir
  )

  yaml_files = fileset(
    local.manifests_dir,
    "*.{yml,yaml}"
  )

  manifest_lists = [
    for file in local.yaml_files :
    provider::kubernetes::manifest_decode_multi(
      "${local.manifests_dir}/${file}"
    )
  ]

  manifest_list = flatten(local.manifest_lists...)

  manifests = {
    for manifest in local.manifest_list :
    join("/", [
      manifest.kind,
      try(manifest.metadata.namespace, "cluster"),
      manifest.metadata.name
    ]) => manifest
  }
}

resource "kubernetes_manifest" "app_manifests" {
  for_each = local.manifests
  manifest = each.value
}

module "cnpg_cluster" {
  count      = var.postgres != null ? 1 : 0
  source     = "../opt/cnpg-cluster"
  app_name   = var.app_name
  namespace  = var.namespace
  pg_version = var.postgres.version
  base_gb    = var.postgres.base_gb
  wal_gb     = var.postgres.wal_gb
  db = {
    name     = var.app_name
    encoding = var.postgres.encoding
    sql      = var.postgres.sql
  }
}
