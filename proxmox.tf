locals {
  cluster_network = {
    mask_bits = "24"
    gateway = "172.21.8.1"
  }

  cluster_nodes = {
    bear-cp1 = {vmid = 811, ipv4 = "172.21.8.11", type = local.node_types.control-plane}
    bear-cp2 = {vmid = 812, ipv4 = "172.21.8.12", type = local.node_types.control-plane}
    bear-cp3 = {vmid = 813, ipv4 = "172.21.8.13", type = local.node_types.control-plane}
    bear-w1 = {vmid = 821, ipv4 = "172.21.8.21", type = local.node_types.worker}
    bear-w2 = {vmid = 822, ipv4 = "172.21.8.22", type = local.node_types.worker}
    bear-w3 = {vmid = 823, ipv4 = "172.21.8.23", type = local.node_types.worker}
    bear-w4 = {vmid = 824, ipv4 = "172.21.8.24", type = local.node_types.worker}
  }
  
  node_types = {
    control-plane = {cores = 3, ram = 3072, disk_size = "128G", k8s_role = "control-plane"}
    worker = {cores = 6, ram = 12288, disk_size = "512G", k8s_role = "worker"}
  }
}


resource "proxmox_vm_qemu" "talos_vms" {
  for_each = local.cluster_nodes
  
  name    = each.key
  vmid    = each.value.vmid
  os_type = "cloud_init"

  tags = "terraform"

  target_node = "bear-pve2"
  agent = 1
  onboot = true

  cpu {
    cores = each.value.type.cores
  }
  memory = each.value.type.ram

  network {
    id = 0
    model = "virtio"
    bridge = "vmbr0"
    tag = 8
  }

  disk {
    type = "cdrom"
    iso = "local:iso/talos-nocloud.iso" 
    slot = "ide0"
  }

  disk {
    type = "cloudinit"
    storage = "local"
    slot = "ide2"
  }

  disk {
    type = "disk"
    storage = "data"
    slot = "virtio0"
    format = "raw"
    size = each.value.type.disk_size
  }

  boot = "order=virtio0;ide0"
  ipconfig0 = "ip=${each.value.ipv4}/${local.cluster_network.mask_bits},gw=${local.cluster_network.gateway}"
}

resource "time_sleep" "wait_20s_for_vm_boot" {
  depends_on = [proxmox_vm_qemu.talos_vms]

  create_duration = "20s"
}
