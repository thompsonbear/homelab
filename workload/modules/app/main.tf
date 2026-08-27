locals {
  manifests_dir = coalesce(var.custom_manifests_dir, "${path.root}/resources/${var.app_name}/manifests")
  manifests = nonsensitive({
    for manifest in flatten([
      for file in fileset(local.manifests_dir, "*.{yml,yaml}") :
      provider::kubernetes::manifest_decode_multi(
        templatefile("${local.manifests_dir}/${file}", { app = local.app })
      )
    ]) : "${manifest.kind}/${manifest.metadata.name}" => manifest
  })

  fqdns = [for label in var.dns.labels : "${label}.${nonsensitive(var.dns.public ? var.base_public_domain : var.base_private_domain)}"]
  app = {
    name            = var.app_name
    namespace       = var.namespace
    tag             = var.image_tag
    fqdn            = local.fqdns[0]
    fqdns           = local.fqdns
    tls_secret_name = "${var.app_name}-tls"
    gateway         = var.dns.public ? var.gateways.public : var.gateways.private
    backend         = var.backend
    postgres = {
      name   = var.app_name
      host   = "${var.app_name}-cnpg-cluster-rw.${var.namespace}.svc.cluster.local"
      port   = 5432
      secret = "${var.app_name}-cnpg-cluster-app"
    }
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
        name  = var.dns.public ? "letsencrypt" : "ejbca"
        kind  = "ClusterIssuer"
        group = var.dns.public ? "cert-manager.io" : "ejbca-issuer.keyfactor.com"
      }
    }
  })
}

resource "unifi_dns_record" "dns_a_records" {
  for_each = toset(local.app.fqdns)
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
      "listeners" = [
        {
          "name"     = local.app.name
          "port"     = 443
          "protocol" = "HTTPS"
          "tls" = {
            "certificateRefs" = [
              {
                "name" = local.app.tls_secret_name
              }
            ]
          }
        }
      ]
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
      "parentRefs" = [
        {
          "kind"        = "ListenerSet"
          "name"        = local.app.name
          "sectionName" = local.app.name
        }
      ]
      "hostnames" = local.app.fqdns
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
              "name"     = local.app.backend.service
              "port"     = local.app.backend.port
              "protocol" = "HTTP"
            }
          ]
        }
      ]
    }
  })
}

module "cnpg_cluster" {
  count                  = var.postgres != null ? 1 : 0
  source                 = "./cnpg-cluster"
  app_name               = local.app.name
  namespace              = local.app.namespace
  cnpg_cluster_chart_tag = var.postgres.chart_tag
  pg_major_version       = var.postgres.version
  replicas               = var.postgres.replicas
  base_gb                = var.postgres.base_gb
  wal_gb                 = var.postgres.wal_gb
  db = {
    name     = local.app.name
    encoding = var.postgres.encoding
    sql      = var.postgres.sql
  }
}

resource "kubernetes_manifest" "app_manifests" {
  depends_on = [module.cnpg_cluster]
  for_each   = local.manifests
  manifest   = each.value
}
