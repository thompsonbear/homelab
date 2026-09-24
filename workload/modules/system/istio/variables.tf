variable "tag" {
  type        = string
  description = "The version tag of the Istio chart/image to install"
}

variable "gateways" {
  type = map(object({
    ip   = string
    name = string
  }))
  description = "The gateways to configure for Istio"
}
