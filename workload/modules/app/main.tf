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

  fqdn        = "${var.dns.labels[0]}.${nonsensitive(var.dns.public ? var.base_public_domain : var.base_private_domain)}"
  fqdns       = [for label in var.dns.labels : "${label}.${nonsensitive(var.dns.public ? var.base_public_domain : var.base_private_domain)}"]
  cert_secret = "${var.app_name}-tls"

  template_vars = {
    app_name     = var.app_name
    namespace    = var.namespace
    tag          = var.image_tag
    fqdn         = local.fqdn
    fqdns        = local.fqdns
    cert_secret  = local.cert_secret
    backend_port = var.backend.port
    postgres     = module.cnpg_cluster.0.db
  }
}

resource "kubectl_manifest" "cert" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = local.cert_secret
      namespace = var.namespace
    }
    spec = {
      secretName  = local.cert_secret
      commonName  = local.fqdn
      dnsNames    = local.fqdns
      duration    = "1128h" # 47 days
      renewBefore = "336h"  # 14 days
      privateKey = {
        algorithm = "ECDSA"
        size      = "384"
        encoding  = "PKCS8"
      }

      usages = ["server auth"]
      issuerRef = {
        name  = var.dns.public ? "letsencrypt" : "ejbca"
        kind  = "ClusterIssuer"
        group = var.dns.public ? "cert-manager.io" : "ejbca-issuer.keyfactor.com"
      }
    }
  })
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
