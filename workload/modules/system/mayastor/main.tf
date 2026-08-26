module "namespace" {
  source     = "../namespace"
  name       = "mayastor"
  privileged = true
}

resource "helm_release" "mayastor" {
  name       = "mayastor"
  chart      = "mayastor"
  repository = "https://openebs.github.io/mayastor-extensions/"
  namespace  = module.namespace.name
  version    = var.tag
  values = [templatefile("${path.module}/resources/values.tftpl", {
    alloy_enabled     = var.alloy_enabled
    loki_enabled      = var.loki_enabled
    agents_ha_enabled = var.agents_ha_enabled
    rest_replicas     = var.rest_replicas
    etcd_replicas     = var.etcd_replicas
    nats_replicas     = var.nats_replicas
  })]
}

resource "kubernetes_storage_class_v1" "storage_classes" {
  depends_on = [helm_release.mayastor]
  count      = 3
  metadata {
    name = "mayastor-${count.index + 1}"
  }
  parameters = {
    protocol = "nvmf"
    repl     = "${count.index + 1}"
  }
  storage_provisioner = "io.openebs.csi-mayastor"
  reclaim_policy      = "Retain"
}

data "kubernetes_nodes" "diskpool_nodes" {
  metadata {
    labels = {
      "openebs.io/engine" = "mayastor"
    }
  }
}

resource "kubectl_manifest" "diskpools" {
  depends_on = [helm_release.mayastor]
  for_each   = { for node in data.kubernetes_nodes.diskpool_nodes.nodes : node.metadata[0].name => node }
  yaml_body = yamlencode({
    apiVersion = "openebs.io/v1beta3"
    kind       = "DiskPool"
    metadata = {
      name      = "${each.key}-dsp"
      namespace = "mayastor"
    }
    spec = {
      node         = each.key
      disks        = ["/dev/disk/by-path/virtio-pci-0000:00:0b.0"]
      maxExpansion = "3TiB"
    }
  })
}
