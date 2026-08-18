variable "tag" {
  type        = string
  description = "The version tag of the Istio chart/image to install"
}

variable "ip_pool" {
  type        = string
  description = "The IP pool subnet to use for Istio gateways (e.g. 10.0.0.1/24)"
}
