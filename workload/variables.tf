variable "az_key_vault_name" {
  type        = string
  description = "Name of the Azure Key Vault to reference for secret values"
  sensitive   = true
}

variable "az_key_vault_rg" {
  type        = string
  description = "Resource Group containing the target Azure Key Vault"
  sensitive   = true
}

variable "environment" {
  type        = string
  description = "The environment type (prod/staging/dev/etc.)"
}

variable "system" {
  type = object({
    cert_manager = object({ chart_tag = string })
    metallb      = object({ chart_tag = string })
    istio        = object({ chart_tag = string })
    csi_nfs      = object({ chart_tag = string })
    mayastor     = object({ chart_tag = string })
    keycloak     = object({ image_tag = string })

    cnpg         = object({
      operator = object({
        image_tag = string
        chart_tag = string
        pg_images = list(object({
          major = number
          image = string
          extensions = optional(list(object({
            name = string
            image = object({
              reference = string
            })
            dynamic_library_path = optional(list(string))
            extension_control_path = optional(list(string))
          })))
        }))
      })
    })

    valkey       = object({
      operator = object({
        chart_tag = string
      })
      chart_tag = string
    })

  })
  description = "system configuration"
}

variable "app_defaults" {
  type = object({
    keycloak = object({
      client_roles = list(string)
    })
    postgres = object({
      version = number
      base_gb = number
      wal_gb = number
      encoding = string
      sql = list(string)
      replicas = number
      extensions = list(object({
        name = string
        create = bool
        preload = bool
      }))
    })
    valkey = object({
      clustered = bool
      chart_tag = string
      shards    = number
      instances = number
      size_gb   = number
    })
  })
}

variable "apps" {
  type = map(object({
    namespace = optional(string, null)

    chart = optional(object({
      name    = optional(string)
      repo    = string
      version = optional(string)
    }), null)

    route = optional(object({
      dns_labels     = optional(list(string))
      https_redirect = optional(bool)
      public         = optional(bool)
      svc_name       = optional(string)
      svc_port       = optional(number)
    }), null)

    keycloak = optional(object({
      redirect_uris = optional(list(string))
      logout_uris   = optional(list(string))
      client_roles  = optional(list(string))
    }), null)

    postgres = optional(object({
      version  = optional(number)
      base_gb  = optional(number)
      wal_gb   = optional(number)
      replicas = optional(number)
      encoding = optional(string)
      sql      = optional(list(string))
      extensions = optional(list(object({
        name    = string
        create  = optional(bool)
        preload = optional(bool)
      })), [])
    }), null)

    valkey = optional(object({
      clustered = optional(bool)
      shards    = optional(number)
      instances = optional(number)
      size_gb   = optional(number)
    }), null)
  }))
}
