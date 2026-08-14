module "akv" {
  source         = "../modules/akv"
  name           = var.az_key_vault_name
  resource_group = var.az_key_vault_rg
}

module "app_namespaces" {
  source   = "./modules/namespace"
  for_each = toset(distinct([ for k, v in var.apps : try(v.namespace, k) ]))
  name     = each.key
}

module "apps" {
  depends_on = [ module.app_namespaces ]
  source   = "./modules/app"
  for_each = var.apps

  namespace = try(each.value.namespace, each.key)

  image_version = each.value.image_version

  chart = {
    name    = try(each.value.chart.name, each.key)
    repo    = each.value.chart.repo
    version = try(each.value.chart.version, each.value.version)
  }

  dns = can(each.value.dns) ? {
    labels = try(each.value.dns.labels, [each.key])
    public = try(each.value.dns.public, false)
    } : {
    labels = [each.key]
  }

  backend = can(each.value.backend) ? {
    service = try(each.value.backend.service, each.key)
    port    = try(each.value.backend.port, 80)
    } : {
    service = each.key
  }

  keycloak = can(each.value.keycloak) ? each.value.keycloak : null
  postgres = can(each.value.postgres) ? each.value.postgres : null
  valkey   = can(each.value.valkey) ? each.value.valkey : null
}
