variable "app_name" {
  type        = string
  description = "Unique name for the application"
}

variable "namespace" {
  type        = string
  description = "The namespace of the app"
}

variable "image_version" {
  type        = string
  description = "The image version of the app"
  default     = "latest"
}

variable "chart" {
  type = object({
    name    = string
    repo    = string
    version = optional(string, null)
  })
  default     = null
  description = "The name, repository, and chart version for the helm chart"
}

variable "manifests_dir" {
  type        = string
  default     = null
  description = "The directory containing any manifest files to apply"
}

variable "dns" {
  type = object({
    labels = list(string)
    public = optional(bool, null)
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
    version  = optional(number, null)
    base_gb  = optional(number, null)
    wal_gb   = optional(number, null)
    replicas = optional(number, null)
    encoding = optional(string, null)
    sql      = optional(list(string), [])
  })
  default = null
}

variable "valkey" {
  type = object({
    size_gb  = optional(number, null)
    replicas = optional(number, null)
  })
  default = null
}
