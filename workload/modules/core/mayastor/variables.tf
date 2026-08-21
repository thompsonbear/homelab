variable "tag" {
  type        = string
  description = "mayastor chart/image version tag - x.y.z"
}

variable "agents_ha_enabled" {
  type        = bool
  description = "enable HA agents"
  default     = false
}

variable "rest_replicas" {
  type        = number
  description = "number of rest replicas"
  default     = 1
}

variable "etcd_replicas" {
  type        = number
  description = "number of etcd replicas"
  default     = 1
}

variable "nats_replicas" {
  type        = number
  description = "number of nats replicas"
  default     = 1
}

variable "loki_enabled" {
  type        = bool
  description = "enable loki"
  default     = false
}

variable "alloy_enabled" {
  type        = bool
  description = "enable alloy"
  default     = false
}
