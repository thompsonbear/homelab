output "cluster" {
  value = {
    talosconfig = data.talos_client_configuration.this.talos_config
    kubeconfig  = talos_cluster_kubeconfig.this.kubeconfig_raw
  }
  sensitive = true
}
