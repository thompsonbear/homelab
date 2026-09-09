resource "random_password" "valkey_password" {
  length  = 32
}

resource "kubernetes_secret_v1" "valkey_secret" {
  metadata {
    name      = "valkey-${var.app_name}-app"
    namespace = var.namespace
  }
  data = {
   password = random_password.valkey_password.result
  }
}

resource "kubectl_manifest" "valkey_cluster" {
  depends_on = [ kubernetes_secret_v1.valkey_secret ]
  yaml_body = yamlencode({
    "apiVersion" = "valkey.io/v1alpha1"
    "kind"       = "ValkeyCluster"
    "metadata" = {
      "name"      = var.app_name
      "namespace" = var.namespace
    }
    "spec" = {
      "users" = [{
        "name" = var.app_name
        "passwordSecret" = {
          "name" = "valkey-${var.app_name}-app"
          "keys" = ["password"]
        }
        "permissions" = "+@all ~* &*"
      }]
      "shards"   = var.shards
      "replicas" = var.replicas - 1
      "persistence" = {
        "size"             = "${var.size_gb}Gi"
        "storageClassName" = "mayastor-1"
      }
    }
  })
}
