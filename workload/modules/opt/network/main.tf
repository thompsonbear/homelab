locals {
  cert_name = "${var.app_name}-tls"
  fqdns     = [for label in var.dns.labels : "${label}.${nonsensitive(var.dns.public ? var.base_public_domain : var.base_private_domain)}"]
}

resource "kubectl_manifest" "cert" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = local.cert_name
      namespace = var.namespace
    }
    spec = {
      secretName  = local.cert_name
      dnsNames    = local.fqdns
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

resource "unifi_dns_record" "vm_dns_a_records" {
  for_each = toset(local.fqdns)
  name     = each.value
  record   = var.dns.public ? var.public_gateway_ip : var.private_gateway_ip
  type     = "A"
}

resource "kubectl_manifest" "listenerset" {
  yaml_body = yamlencode({
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "ListenerSet"
    "metadata" = {
      name      = var.app_name
      namespace = var.namespace
    }
    "spec" = {
      "parentRef" = {
        "kind"      = "Gateway"
        "namespace" = "istio-system"
        "name"      = var.dns.public ? "public" : "private"
      }
      "listeners" = [
        {
          "name"     = var.app_name
          "port"     = 443
          "protocol" = "HTTPS"
          "tls" = {
            "certificateRefs" = [
              {
                "name" = local.cert_name
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
      name      = var.app_name
      namespace = var.namespace
    }
    "spec" = {
      "parentRefs" = [
        {
          "kind"        = "ListenerSet"
          "name"        = var.app_name
          "sectionName" = var.app_name
        }
      ]
      "hostnames" = local.fqdns
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
              "name"     = var.backend.service
              "port"     = var.backend.port
              "protocol" = "HTTP"
            }
          ]
        }
      ]
    }
  })
}
