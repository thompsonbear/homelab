locals {
  resources_dir = "${path.root}/resources/${var.name}"
  base_domain   = var.config.route.public ? var.context.base_public_domain : var.context.base_private_domain
  fqdns = [ for label in var.config.route.dns_labels : "${label}.${local.base_domain}" ]

  app = {
    name            = var.name
    namespace       = var.config.namespace
    fqdn            = local.fqdns[0]
    fqdns           = local.fqdns
    tls_secret_name = "${var.name}-tls"
    gateway         = var.config.route.public ? var.context.gateways.public : var.context.gateways.private
    svc_name        = var.config.route.svc_name
    svc_port        = var.config.route.svc_port
    vars            = var.config.template_vars
    postgres = {
      name   = var.name
      host   = "postgres-${var.name}-rw.${var.config.namespace}.svc.cluster.local"
      port   = 5432
      secret = "postgres-${var.name}-app"
    }
    valkey = {
      name   = var.name
      host   = "valkey-${var.name}.${var.config.namespace}.svc.cluster.local"
      port   = 6379
      secret = "valkey-${var.name}-app"
    }
  }

  listeners = [for fqdn in local.fqdns : {
    "name"     = fqdn
    "hostname" = fqdn
    "port"     = 443
    "protocol" = "HTTPS"
    "tls" = {
      "certificateRefs" = [
        {
          "name" = local.app.tls_secret_name
        }
      ]
    }
  }]

  manifests = {
    for manifest in flatten([
      for file in fileset("${local.resources_dir}/manifests", "*.{yml,yaml,yml.tftpl,yaml.tftpl}") :
      provider::kubernetes::manifest_decode_multi(
        nonsensitive(templatefile("${local.resources_dir}/manifests/${file}", { app = local.app }))
      )
    ]) : "${manifest.kind}/${manifest.metadata.name}" => manifest
  }
}


resource "kubectl_manifest" "cert" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = local.app.tls_secret_name
      namespace = local.app.namespace
    }
    spec = {
      secretName  = local.app.tls_secret_name
      dnsNames    = local.app.fqdns
      duration    = "1080h" # 45 days
      renewBefore = "360h"  # 15 days
      privateKey = {
        algorithm = "ECDSA"
        size      = 384
        encoding  = "PKCS8"
      }

      usages = ["server auth"]
      issuerRef = {
        name  = var.config.route.public ? "letsencrypt" : "ejbca"
        kind  = "ClusterIssuer"
        group = var.config.route.public ? "cert-manager.io" : "ejbca-issuer.keyfactor.com"
      }
    }
  })
}

resource "unifi_dns_record" "dns_a_records" {
  for_each = nonsensitive(toset(local.app.fqdns))
  name     = each.value
  record   = local.app.gateway.ip
  type     = "A"
}

resource "kubectl_manifest" "listenerset" {
  depends_on = [kubectl_manifest.cert]
  yaml_body = yamlencode({
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "ListenerSet"
    "metadata" = {
      name      = local.app.name
      namespace = local.app.namespace
    }
    "spec" = {
      "parentRef" = {
        "kind"      = "Gateway"
        "namespace" = "istio-system"
        "name"      = local.app.gateway.name
      }
      "listeners" = [for fqdn in local.app.fqdns : {
        "name"     = fqdn
        "hostname" = fqdn
        "port"     = 443
        "protocol" = "HTTPS"
        "tls" = {
          "certificateRefs" = [
            {
              "name" = local.app.tls_secret_name
            }
          ]
        }
      }]
    }
  })
}

resource "kubectl_manifest" "httproute" {
  yaml_body = yamlencode({
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "HTTPRoute"
    "metadata" = {
      name      = local.app.name
      namespace = local.app.namespace
    }
    "spec" = {
      "parentRefs" = [{
        "kind" = "ListenerSet"
        "name" = local.app.name
      }]
      "rules" = [
        {
          "matches" = [
            {
              "path" = {
                "type"  = "PathPrefix"
                "value" = "/"
              }
            }
          ]
          "backendRefs" = [
            {
              "name"     = var.config.route.svc_name
              "port"     = var.config.route.svc_port
              "protocol" = "HTTP"
            }
          ]
        }
      ]
    }
  })
}

module "cnpg_cluster" {
  count            = var.config.postgres != null ? 1 : 0
  source           = "./cnpg-cluster"
  app_name         = local.app.name
  namespace        = local.app.namespace
  pg_major_version = var.config.postgres.version
  instances         = var.config.postgres.instances
  base_gb          = var.config.postgres.base_gb
  wal_gb           = var.config.postgres.wal_gb
  db = {
    name       = local.app.name
    encoding   = var.config.postgres.encoding
    sql        = var.config.postgres.sql
    extensions = var.config.postgres.extensions
  }
}

module "valkey" {
  count     = var.config.valkey != null ? 1 : 0
  source    = "./valkey"
  app_name  = local.app.name
  namespace = local.app.namespace
  tag       = var.config.valkey.chart_tag
  clustered = var.config.valkey.clustered
  shards    = var.config.valkey.shards
  instances = var.config.valkey.instances
  size_gb   = var.config.valkey.size_gb
}


resource "kubernetes_manifest" "app_manifests" {
  depends_on = [module.cnpg_cluster]
  for_each   = local.manifests
  manifest   = each.value
}

resource "helm_release" "chart" {
  count      = var.config.chart != null ? 1 : 0
  chart      = var.config.chart.name
  repository = var.config.chart.repo
  name       = var.name
  namespace  = var.config.namespace
  version    = var.config.chart.version
  values     = try([templatefile("${local.resources_dir}/helm/values.yaml.tftpl", { app = local.app })], [])
}
