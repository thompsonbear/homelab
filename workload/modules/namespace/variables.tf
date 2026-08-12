variable "name" {
  type        = string
  description = "The name of the namespace"
}

variable "privileged" {
  type        = bool
  description = "Whether the namespace should be privileged"
  default     = false
}

variable "istio_ambient" {
  type        = bool
  description = "Whether the namespace should be added Istio ambient service mesh"
  default     = true
}
