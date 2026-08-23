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
    cert_manager_tag = string
    metallb_tag      = string
    istio_tag        = string
    mayastor_tag     = string
    cnpg = object({
      image_tag = string
      chart_tag = string
    })
  })
  description = "system chart/image version tags - x.y.z"
}

variable "apps" {
  type = map(object({
    namespace     = string
    image_version = string
    chart = object({
      name    = optional(string)
      repo    = string
      version = optional(string)
    })
    dns = object({
      labels = optional(list(string))
      public = optional(bool)
    })
    backend = optional(object({
      service = optional(string)
      port    = optional(number)
    }))
    keycloak = optional(object({
      redirect_uris = optional(list(string))
      logout_uris   = optional(list(string))
      client_roles  = optional(list(string))
    }))
    postgres = optional(object({
      base_gb  = optional(number)
      wal_gb   = optional(number)
      replicas = optional(number)
    }))
    valkey = optional(object({
      size_gb  = optional(number)
      replicas = optional(number)
    }))
  }))
}
