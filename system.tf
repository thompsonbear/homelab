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
  depends_on = [kubectl_manifest.metallb-namespace]

  name = "metallb"
  namespace = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart = "metallb"

  version = "0.15.2" # Chart version historically matches app version
  values = [
    file("${path.root}/config/metallb-values.yaml")
  ]
}

resource "kubectl_manifest" "metallb_ip_address_pool" {
  depends_on = [helm_release.metallb]
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

# ---- Traefik -----
resource "helm_release" "traefik" {
  depends_on = [kubectl_manifest.metallb_ip_address_pool]

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
