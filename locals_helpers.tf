locals {
  all_workloads            = merge(local.workload.core, local.workload.ingress, local.workload.storage, local.workload.idp, local.workload.app)
  privileged_workloads     = { for k, v in local.all_workloads : k => v if can(v["privileged"]) ? v.privileged : false }
  non_privileged_workloads = { for k, v in local.all_workloads : k => v if can(v["privileged"]) ? !v.privileged : true }

  manifests = merge([
    for group, group_items in local.workload : merge([
      for workload_key, workload_item in group_items :
      (
        can(workload_item.manifests)
        ? {
          for manifest_key, manifest in workload_item.manifests :
          "${workload_key}.${manifest_key}" => merge(
            manifest,
            {
              group         = group
              pre_install   = try(manifest.pre_install, false)
              template_file = manifest.template_file
              vars          = manifest.vars
            }
          )
        }
        : {}
      )
    ]...)
  ]...)

  pre_install_manifests = { for k, v in local.manifests : k => v if v.pre_install == true }
  core_manifests        = { for k, v in local.manifests : k => v if v.group == "core" && v.pre_install == false }
  ingress_manifests     = { for k, v in local.manifests : k => v if v.group == "ingress" && v.pre_install == false }
  storage_manifests     = { for k, v in local.manifests : k => v if v.group == "storage" && v.pre_install == false }
  idp_manifests         = { for k, v in local.manifests : k => v if v.group == "idp" && v.pre_install == false }
  app_manifests         = { for k, v in local.manifests : k => v if v.group == "app" && v.pre_install == false }

  oauth_workloads       = { for k, v in local.all_workloads : k => v if can(v["auth_type"]) && v.auth_type == "oauth" }
  oauth_proxy_workloads = { for k, v in local.all_workloads : k => v if can(v["auth_type"]) && v.auth_type == "oauth_proxy" }

  oauth_client_roles = merge([
    for k, v in merge(local.oauth_workloads, local.oauth_proxy_workloads) : (
      can(v.oauth_config.client_roles) && try(v.auth_type == "oauth", false) ? {
        for role in v.oauth_config.client_roles :
        "${k}:${role}" => {
          client = k
          role   = role
        }
        } : {
        "${k}:admin" = {
          client = k
          role   = "admin"
        }
      }
    )
  ]...)

  kv_apps = { for k, v in local.all_workloads : k => v if can(v["kv"]) }
  db_apps = { for k, v in local.all_workloads : k => v if can(v["db"]) }
}
