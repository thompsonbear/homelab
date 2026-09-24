variable "name" {
  type        = string
  description = "Unique name for the application"
}

variable "context" {
  type = any
}

variable "config" {
  type        = object({
    namespace = string
    template_vars = optional(map(string), {})

    route = object({
      dns_labels = list(string)
      public = bool
      https_redirect = bool
      svc_name = string
      svc_port = number
    })

    chart = optional(object({
      name    = string
      repo    = string
      version = string
    }), null)

    keycloak = optional(object({
      redirect_uris = list(string)
      logout_uris   = list(string)
      client_roles  = list(string)
    }), null)

    postgres = optional(object({
      version  = number
      base_gb  = number
      wal_gb   = number
      replicas = number
      encoding = string
      sql      = list(string)
      extensions = list(object({
        name    = string
        create  = bool
        preload = bool
      }))
    }), null)

    valkey = optional(object({
      clustered = bool
      size_gb   = number
      shards    = number
      instances = number
    }), null)
  })
}
