resource "random_password" "valkey_password" {
  length = 32
}
# {
#   "nodes": [
#     { "host": "10.0.0.1", "port": 6379 },
#     { "host": "10.0.0.2", "port": 6379 },
#     { "host": "10.0.0.3", "port": 6379 }
#   ],
#   "options": {
#     "redisOptions": {
#       "password": "your-cluster-password",
#       "tls": {}
#     }
#   }
# }

locals {
  valkey_nodes = [ for s in range(var.shards) : [
    for r in range(var.replicas) : {
      "host" = "valkey-${var.app_name}-${s}-${r}-0",
      "port" = 6379
    }
  ]]

  enc_cluster_config = base64encode(jsonencode({
    nodes = local.valkey_nodes
    options = {
      redisOptions = {
        username = var.app_name
        password = random_password.valkey_password.result
      }
    }
  }))

  ioredis_uri = "ioredis://${local.enc_cluster_config}"
}

resource "kubernetes_secret_v1" "valkey_secret" {
  metadata {
    name      = "valkey-${var.app_name}-app"
    namespace = var.namespace
  }
  data = {
    ioredis_uri = local.ioredis_uri
    password = random_password.valkey_password.result
  }
}

resource "kubectl_manifest" "valkey_cluster" {
  depends_on = [kubernetes_secret_v1.valkey_secret]
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
