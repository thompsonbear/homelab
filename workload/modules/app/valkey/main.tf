resource "random_password" "valkey_password" {
  length = 32
}

locals {
  valkey_cluster_nodes = [for s in range(var.shards) : [
    for i in range(var.instances) : {
      "host" = "valkey-${var.app_name}-${s}-${i}-0",
      "port" = 6379
    }
  ]]

  cluster_config = var.clustered ? jsonencode({
    nodes = local.valkey_cluster_nodes
    options = {
      redisOptions = {
        username = var.app_name
        password = random_password.valkey_password.result
      }
    }
  }) : null
}

resource "kubernetes_secret_v1" "valkey_secret" {
  metadata {
    name      = "valkey-${var.app_name}-app"
    namespace = var.namespace
  }
  data = {
    "${var.app_name}" = random_password.valkey_password.result
  }
}

resource "helm_release" "valkey" {
  count      = var.clustered ? 0 : 1
  name       = "valkey"
  chart      = "valkey"
  repository = "https://valkey.io/valkey-helm/"
  namespace  = var.namespace
  version    = var.tag
  set = [{
    name        = "auth.aclUsers.${var.app_name}.permissions"
    value       = "~* &* +@all"
  }]
  values = [templatefile("${path.module}/resources/values.yaml", {
    app_name    = var.app_name
    instances   = var.instances
    size_gb     = var.size_gb
    user_secret = kubernetes_secret_v1.valkey_secret.metadata[0].name
  })]
}

resource "kubectl_manifest" "valkey_clustered" {
  count = var.clustered ? 1 : 0
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
          "name" = kubernetes_secret_v1.valkey_secret.metadata[0].name
          "keys" = [var.app_name]
        }
        "permissions" = "+@all ~* &*"
      }]
      "shards"   = var.shards
      "replicas" = var.instances - 1
      "persistence" = {
        "size"             = "${var.size_gb}Gi"
        "storageClassName" = "mayastor-1"
      }
    }
  })
}
