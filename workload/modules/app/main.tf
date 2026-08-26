locals {
  manifests_dir = coalesce(
    var.manifests_dir,
    "${path.root}/resources/${var.app_name}/manifests"
  )

  yaml_files = fileset(
    local.manifests_dir,
    "*.{yml,yaml}"
  )

  manifest_lists = [
    for file in local.yaml_files :
    provider::kubernetes::manifest_decode_multi(
      templatefile("${local.manifests_dir}/${file}", local.template_vars)
    )
  ]

  manifests = {
    for manifest in flatten(local.manifest_lists) :
    join("/", [
      manifest.kind,
      try(manifest.metadata.namespace, "cluster"),
      manifest.metadata.name
    ]) => manifest
  }


  template_vars = {
    app_name     = var.app_name
    namespace    = var.namespace
    tag          = var.image_tag
    fqdn         = module.network.fqdns[0]
    fqdns        = module.network.fqdns
    tls_secret   = module.network.cert_name
    backend_port = var.backend.port
    postgres     = module.cnpg_cluster.0.db
  }
}

module "network" {
  source              = "../opt/network"
  app_name            = var.app_name
  namespace           = var.namespace
  base_public_domain  = var.base_public_domain
  base_private_domain = var.base_private_domain
  dns                 = var.dns
  backend             = var.backend
}

module "cnpg_cluster" {
  count      = var.postgres != null ? 1 : 0
  source     = "../opt/cnpg-cluster"
  app_name   = var.app_name
  namespace  = var.namespace
  tag        = var.postgres.chart_tag
  pg_version = var.postgres.version
  replicas   = var.postgres.replicas
  base_gb    = var.postgres.base_gb
  wal_gb     = var.postgres.wal_gb
  db = {
    name     = var.app_name
    encoding = var.postgres.encoding
    sql      = var.postgres.sql
  }
}

resource "kubernetes_manifest" "app_manifests" {
  depends_on = [module.cnpg_cluster]
  for_each   = local.manifests
  manifest   = each.value
}
