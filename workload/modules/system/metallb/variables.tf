variable "tag" {
  type        = string
  description = "The image tag to use for metallb"
}

variable "ip_pool" {
  type        = string
  description = "The IP range/subnet to use for MetalLB"
}
