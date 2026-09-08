resource "kubectl_manifest" "valkey_cluster" {
  yaml_body = yamlencode({
    "apiVersion" = "valkey.io/v1alpha1"
    "kind"       = "ValkeyCluster"
    "metadata" = {
      "name"      = "${var.app_name}-kv"
      "namespace" = var.namespace
    }
    "spec" = {
      "shards"   = var.shards
      "replicas" = var.replicas
      "persistence" = {
        "size"             = "${var.size_gb}Gi"
        "storageClassName" = "mayastor-1"
      }
    }
  })
}
