vm_name_prefix = "bear"

pve_nodes = {
  bear-pve2 = {
    vm_storage = {
      disk = "data"
      iso  = "local"
      init = "local"
    }
  }
}

vms = [
  { vcores = 6, ram_mb = 6144, os_disk_gb = 64, role = "control-plane" },
  { vcores = 8, ram_mb = 8192, os_disk_gb = 64, data_disk_gb = 512, role = "worker" },
  { vcores = 8, ram_mb = 8192, os_disk_gb = 64, data_disk_gb = 512, role = "worker" },
  { vcores = 8, ram_mb = 8192, os_disk_gb = 64, data_disk_gb = 512, role = "worker" }
]

talos_version = "v1.13.7"

talos_iso_filename = "talos-v13-7.iso"
