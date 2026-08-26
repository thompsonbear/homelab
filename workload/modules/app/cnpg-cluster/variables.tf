variable "app_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "cnpg_cluster_chart_tag" {
  type = string
}

variable "pg_major_version" {
  type = number
}

variable "replicas" {
  type = number
}

variable "base_gb" {
  type = number
}

variable "wal_gb" {
  type = number
}

variable "db" {
  type = object({
    name     = string
    encoding = string
    sql      = list(string)
  })
}
