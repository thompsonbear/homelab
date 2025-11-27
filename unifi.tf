resource "unifi_dns_record" "vm_dns_entries" {
  for_each = local.vm.nodes

  name        = "${each.key}.${local.vm.network.localdomain}"
  value       = each.value.ipv4
  port        = 0
  record_type = "A"
}
