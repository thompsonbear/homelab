resource "unifi_dns_record" "vm_dns_entries" {
  for_each = local.cluster_nodes
  
  name = "${each.key}.bear.home"
  value = each.value.ipv4
  port = 0
  record_type = "A"
}
