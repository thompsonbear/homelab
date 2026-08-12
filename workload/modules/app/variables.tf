variable "namespace" {
  type        = string
  description = "The namespace of the app"
}

variable "version" {
  type        = string
  description = "The image version of the app"
  default     = "latest"
}

variable "chart" {
  type = object({
    name    = string
    repo    = string
    version = optional(string, "latest")
  })
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
  type = optional(object({
    redirect_uris = optional(list(string), [])
    logout_uris   = optional(list(string), [])
    client_roles  = optional(list(string), ["admin"])
  }))
}

variable "postgres" {
  type = optional(object({
    base_gb  = optional(number, 20)
    wal_gb   = optional(number, 5)
    replicas = optional(number, 2)
  }))
}

variable "valkey" {
  type = optional(object({
    size_gb  = optional(number, 10)
    replicas = optional(number, 2)
  }))
}
