locals {
  default_pve_node = keys(var.pve_nodes)[0]
}

resource "proxmox_vm_qemu" "vms" {
  for_each = var.vms

  name    = each.key
  vmid    = tonumber(join("", slice(split(".", each.value.ip), 2, 4)))
  os_type = "cloud_init"

  tags        = "${var.environment},${each.value.role}"
  description = "- environment: ${var.environment}\n- role: ${each.value.role}\n- vcores: ${each.value.vcores}\n- memory: ${each.value.ram_mb / 1024}GB"

  target_node        = each.value.pve_node != null ? each.value.pve_node : local.default_pve_node
  agent              = 1
  start_at_node_boot = true

  cpu {
    cores = each.value.vcores
  }
  memory = each.value.ram_mb

  network {
    id     = 0
    model  = var.pve_nodes[each.value.pve_node != null ? each.value.pve_node : local.default_pve_node].vm_network.iface_model
    bridge = var.pve_nodes[each.value.pve_node != null ? each.value.pve_node : local.default_pve_node].vm_network.bridge_iface
    tag    = var.vlan_tag
  }

  disk {
    type = "cdrom"
    iso  = "${var.pve_nodes[each.value.pve_node != null ? each.value.pve_node : local.default_pve_node].vm_storage.iso}:iso/${var.iso_filename}"
    slot = "ide0"
  }

  disk {
    type    = "cloudinit"
    storage = var.pve_nodes[each.value.pve_node != null ? each.value.pve_node : local.default_pve_node].vm_storage.init
    slot    = "ide2"
  }

  disk {
    type    = "disk"
    storage = var.pve_nodes[each.value.pve_node != null ? each.value.pve_node : local.default_pve_node].vm_storage.disk
    slot    = "virtio0"
    format  = "raw"
    size    = "${each.value.os_disk_gb}G"
  }

  disk {
    type    = each.value.data_disk_gb > 0 ? "disk" : "ignore"
    storage = var.pve_nodes[each.value.pve_node != null ? each.value.pve_node : local.default_pve_node].vm_storage.disk
    slot    = "virtio1"
    format  = "raw"
    size    = each.value.data_disk_gb > 0 ? "${each.value.data_disk_gb}G" : null
  }

  boot      = "order=virtio0;ide0"
  ipconfig0 = "ip=${each.value.ip}/${split("/", var.subnet)[1]},gw=${split("/", var.subnet)[0]}"

  startup_shutdown {
    order            = null
    shutdown_timeout = null
    startup_delay    = null
  }
}
