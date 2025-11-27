resource "proxmox_vm_qemu" "talos_vms" {
  for_each = local.vm.nodes

  name    = each.key
  vmid    = each.value.vmid
  os_type = "cloud_init"

  tags = "terraform"

  target_node = "bear-pve2"
  agent       = 1
  onboot      = true

  cpu {
    cores = each.value.type.cores
  }
  memory = each.value.type.ram

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 8
  }

  disk {
    type = "cdrom"
    iso  = "local:iso/talos-nocloud.iso"
    slot = "ide0"
  }

  disk {
    type    = "cloudinit"
    storage = "local"
    slot    = "ide2"
  }

  disk {
    type    = "disk"
    storage = "data"
    slot    = "virtio0"
    format  = "raw"
    size    = each.value.type.disk_size
  }

  boot      = "order=virtio0;ide0"
  ipconfig0 = "ip=${each.value.ipv4}/${local.vm.network.mask_bits},gw=${local.vm.network.gateway}"
}

resource "time_sleep" "wait_20s_for_vm_boot" {
  depends_on = [proxmox_vm_qemu.talos_vms]

  create_duration = "20s"
}
