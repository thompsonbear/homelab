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
  timeout    = 900
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

resource "kubectl_manifest" "diskpools" {
  depends_on = [helm_release.mayastor]
  for_each   = toset(var.diskpool_nodes)
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

resource "kubernetes_persistent_volume_claim_v1" "nfs_pvc" {
  depends_on = [helm_release.mayastor, kubernetes_storage_class_v1.storage_classes]
  metadata {
    name      = "nfs-pvc"
    namespace = module.namespace.name
  }
  spec {
    storage_class_name = "mayastor-2"
    access_modes       = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.nfs_storage_gb}Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "nfs_server_deploy" {
  metadata {
    name      = "nfs-server"
    namespace = module.namespace.name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        role = "nfs-server"
      }
    }
    template {
      metadata {
        labels = {
          role = "nfs-server"
        }
      }
      spec {
        volume {
          name = "nfs-vol"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.nfs_pvc.metadata[0].name
          }
        }
        restart_policy = "Always"
        container {
          name  = "nfs-server"
          image = "itsthenetwork/nfs-server-alpine"
          env {
            name  = "SHARED_DIRECTORY"
            value = "/nfsshare"
          }
          port {
            name           = "nfs"
            container_port = 2049
          }
          security_context {
            privileged = true
          }
          volume_mount {
            mount_path = "/nfsshare"
            name       = "nfs-vol"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "nfs_server_svc" {
  metadata {
    name      = "nfs-server"
    namespace = module.namespace.name
  }
  spec {
    port {
      name = "nfs"
      port = 2049
    }
    selector = {
      role = "nfs-server"
    }
  }
}

resource "kubernetes_storage_class_v1" "nfs_storage_class" {
  metadata {
    name = "mayastor-nfs"
  }
  parameters = {
    server = "${kubernetes_service_v1.nfs_server_svc.metadata[0].name}.${module.namespace.name}.svc.cluster.local"
    share  = "/"
  }
  storage_provisioner = "nfs.csi.k8s.io"
  reclaim_policy      = "Retain"
  volume_binding_mode = "Immediate"
  mount_options       = ["nfsvers=4.1"]
}
