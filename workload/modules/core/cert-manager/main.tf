module "namespace" {
  source     = "../namespace"
  name       = "cert-manager"
  privileged = true
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  namespace  = module.namespace.name
  version    = var.tag

  values = [templatefile("${path.module}/resources/values.tftpl", { replicas = var.replicas })]
}

resource "kubernetes_secret_v1" "cloudflare_token" {
  metadata {
    name      = "cloudflare-token-secret"
    namespace = module.namespace.name
  }
  type = "Opaque"
  data = {
    "cloudflare-token" = var.cloudflare_token
  }
}

resource "kubectl_manifest" "public_acme_issuer" {
  depends_on = [helm_release.cert_manager, kubernetes_secret_v1.cloudflare_token]
  yaml_body = yamlencode({
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "public-acme"
    }
    "spec" = {
      "acme" = {
        "email" = var.acme_email
        "privateKeySecretRef" = {
          "name" = "public-acme"
        }
        "server" = var.environment == "prod" ? "https://acme-v02.api.letsencrypt.org/directory" : "https://acme-staging-v02.api.letsencrypt.org/directory"
        "solvers" = [{
          "dns01" = {
            "cloudflare" = {
              "apiTokenSecretRef" = {
                "key"  = "cloudflare-token"
                "name" = "cloudflare-token-secret"
              }
              "email" = var.acme_email
            }
          }
          "selector" = {
            "dnsZones" = [
              var.base_public_domain
            ]
          }
        }]
      }
    }
  })
}
