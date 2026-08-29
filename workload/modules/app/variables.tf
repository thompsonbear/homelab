variable "app_name" {
  type        = string
  description = "Unique name for the application"
}

variable "namespace" {
  type        = string
  description = "The namespace of the app"
}

variable "replicas" {
  type        = number
  description = "The number of replicas for the app"
  default     = 1
}

variable "context" {
  type = object({
    base_public_domain  = string
    base_private_domain = string
    gateways = map(object({
      ip   = string
      name = string
    }))
  })
}

variable "image_tag" {
  type        = string
  description = "The image version of the app"
  default     = "latest"
}

variable "secrets" {
  type        = map(map(string))
  sensitive   = true
  description = "Secrets to create in the app namespace"
  default     = {}
}

variable "chart" {
  type = object({
    name    = string
    repo    = string
    version = optional(string, "latest")
  })
  default     = null
  description = "The name, repository, and chart version for the helm chart"
}

variable "dns" {
  type = object({
    labels = list(string)
    public = optional(bool, false)
  })
}

variable "backend" {
  type = object({
    service = string
    port    = optional(number, 80)
  })
}

variable "keycloak" {
  type = object({
    redirect_uris = optional(list(string), [])
    logout_uris   = optional(list(string), [])
    client_roles  = optional(list(string), ["admin"])
  })
  default = null
}

variable "postgres" {
  type = object({
    chart_tag = optional(string, "0.8.1")
    version   = optional(number, 18)
    base_gb   = optional(number, 10)
    wal_gb    = optional(number, 0)
    replicas  = optional(number, 2)
    encoding  = optional(string, "UTF8")
    sql       = optional(list(string), [])
  })
  default = null
}

variable "valkey" {
  type = object({
    size_gb  = optional(number, 5)
    replicas = optional(number, 2)
  })
  default = null
}
