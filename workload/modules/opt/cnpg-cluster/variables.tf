variable "namespace" {
  type        = string
  description = "Namespace for the CNPG cluster"
}

variable "tag" {
  type        = string
  description = "Tag of the cluster chart to deploy"
  default     = "0.8.1"
}

variable "pg_version" {
  type        = number
  description = "Major version of PostgreSQL to deploy"
  default     = 18
}

variable "replicas" {
  type        = number
  description = "The number of local replicas for the cluster"
  default     = 2
}

variable "data_gb" {
  type        = number
  description = "Size of the data storage in GB"
  default     = 10
}

variable "wal_gb" {
  type        = number
  description = "Size of the WAL storage in GB (0 = disabled)"
  default     = 0
}

variable "db" {
  type = object({
    name     = string
    locale   = optional(string, "en_US.utf8")
    encoding = optional(string, "UTF8")
    sql      = optional(list(string), [])
  })
  description = "Database parameters to set during initialization of the cluster"
}
