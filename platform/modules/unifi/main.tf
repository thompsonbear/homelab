resource "unifi_dns_record" "vm_dns_a_records" {
  for_each = var.vms

  name   = "${each.key}.${var.dns_search_domain}"
  record = each.value.ip
  type   = "A"
}

data "unifi_firewall_zone" "vm_zone" {
  name = var.firewall_zone
}

resource "unifi_network" "vm_network" {
  name             = "${title(var.environment)} VMs"
  subnet           = var.subnet
  vlan_id          = var.vlan_tag
  domain_name      = var.dns_search_domain
  dhcp_enabled     = false
  purpose          = "corporate"
  firewall_zone_id = data.unifi_firewall_zone.vm_zone.id
}
