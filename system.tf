# ---- MetalLB -----
resource "kubectl_manifest" "metallb-namespace" {
  depends_on = [data.talos_cluster_health.this]

  yaml_body = <<YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: metallb
      labels:
        kubernetes.io/metadata.name: metallb-system
        pod-security.kubernetes.io/audit: privileged
        pod-security.kubernetes.io/enforce: privileged
        pod-security.kubernetes.io/enforce-version: latest
        pod-security.kubernetes.io/warn: privileged
  YAML
}

resource "helm_release" "metallb" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.metallb-namespace]

  name = "metallb"
  namespace = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart = "metallb"
  version = "0.15.2"
  values = [
    file("${path.root}/config/metallb-values.yaml")
  ]
}

resource "kubectl_manifest" "metallb_ip_address_pool" {
  depends_on = [data.talos_cluster_health.this, helm_release.metallb]
  yaml_body = <<YAML
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: bear-home
      namespace: metallb
    spec:
      addresses:
      - 172.21.8.100-172.21.8.199
  YAML
}

resource "kubectl_manifest" "metallb_l2advertisement" {
  depends_on = [data.talos_cluster_health.this, helm_release.metallb]
  yaml_body = <<YAML
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: bear-home
      namespace: metallb
    spec:
      ipAddressPools:
      - bear-home
      interfaces:
      - eth0
  YAML
}

# ---- Traefik -----
resource "helm_release" "traefik" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.metallb_ip_address_pool]

  name = "traefik"
  namespace = "traefik"
  create_namespace = true
  repository = "https://traefik.github.io/charts"
  chart = "traefik"
  upgrade_install = "true"
  version = "37.3.0" # Chart version historically matches app version
  values = [
    file("${path.root}/config/traefik-values.yaml")
  ]
}

# ---- cert-manager -----
resource "helm_release" "cert-manager" {
  depends_on = [data.talos_cluster_health.this]

  name = "cert-manager"
  namespace = "cert-manager"
  create_namespace = true
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  version = "1.19.1"
  values = [
    file("${path.root}/config/cert-manager-values.yaml")
  ]
}

locals {
  letsencrypt_endpoints = {
    prod = "https://acme-v02.api.letsencrypt.org/directory"
    staging = "https://acme-staging-v02.api.letsencrypt.org/directory"
  }
}

resource "kubectl_manifest" "cloudflare-token-secret" {
  depends_on = [data.talos_cluster_health.this, helm_release.cert-manager]

  yaml_body = <<YAML
    apiVersion: v1
    kind: Secret
    metadata:
      name: cloudflare-token-secret
      namespace: cert-manager
    type: Opaque
    data:
      cloudflare-token: ${base64encode(var.cloudflare_token)}
  YAML
}

resource "kubectl_manifest" "letsencrypt-clusterissuers" {
  depends_on = [data.talos_cluster_health.this, helm_release.cert-manager, kubectl_manifest.cloudflare-token-secret]
  for_each = local.letsencrypt_endpoints

  yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-${each.key}
    spec:
      acme:
        email: ${var.acme_email}
        privateKeySecretRef:
          name: letsencrypt-${each.key}
        server: ${each.value}
        solvers:
        - dns01:
            cloudflare:
              apiTokenSecretRef:
                key: cloudflare-token
                name: cloudflare-token-secret
              email: ${var.acme_email}
          selector:
            dnsZones:
            - ${var.base_public_domain}
  YAML
}

# ---- Longhorn -----
resource "kubectl_manifest" "longhorn-system-namespace" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.letsencrypt-clusterissuers, helm_release.traefik, kubectl_manifest.metallb_ip_address_pool]

  yaml_body = <<YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: longhorn-system
      labels:
        kubernetes.io/metadata.name: longhorn-system
        pod-security.kubernetes.io/audit: privileged
        pod-security.kubernetes.io/enforce: privileged
        pod-security.kubernetes.io/enforce-version: latest
        pod-security.kubernetes.io/warn: privileged
  YAML
}

resource "helm_release" "longhorn" {
  depends_on = [data.talos_cluster_health.this, kubectl_manifest.longhorn-system-namespace]
  name = "longhorn"
  namespace = "longhorn-system"
  repository = "https://charts.longhorn.io"
  chart = "longhorn"
  version = "1.10.1"
  timeout = 600
  upgrade_install = "true"
  values = [
    file("${path.root}/config/longhorn-values.yaml")
  ]
}
