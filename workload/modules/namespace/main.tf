resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.name
    labels = {
      "kubernetes.io/metadata.name" = var.name

      "istio.io/dataplane-mode" = var.istio_ambient ? "ambient" : "none"

      "pod-security.kubernetes.io/audit" = var.privileged ? "privileged" : "baseline"
      "pod-security.kubernetes.io/audit-version" = "latest"

      "pod-security.kubernetes.io/enforce" = var.privileged ? "privileged" : "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"

      "pod-security.kubernetes.io/warn" = var.privileged ? "privileged" : "baseline"
      "pod-security.kubernetes.io/warn-version" = "latest"
    }
  }

}
