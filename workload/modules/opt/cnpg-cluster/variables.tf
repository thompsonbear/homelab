variable "app_name" {
  type        = string
  description = "Name of the related application"
}

variable "namespace" {
  type        = string
  description = "Namespace for the CNPG cluster"
}

variable "tag" {
  type        = string
  description = "Tag of the cluster chart to deploy"
}

variable "pg_version" {
  type        = number
  description = "Major version of PostgreSQL to deploy"
}

variable "replicas" {
  type        = number
  description = "The number of local replicas for the cluster"
}

variable "base_gb" {
  type        = number
  description = "Size of the base storage in GB"
}

variable "wal_gb" {
  type        = number
  description = "Size of the WAL storage in GB (0 = disabled)"
}

variable "db" {
  type = object({
    name     = string
    encoding = string
    sql      = list(string)
  })
  description = "Database parameters to set during initialization of the cluster"
}
