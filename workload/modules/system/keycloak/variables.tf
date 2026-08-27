variable "tag" {
  type        = string
  description = "The tag of the Keycloak image to use"
}

variable "base_public_domain" {
  type        = string
  description = "The base public domain to use for Keycloak"
}

variable "gateways" {
  type = map(object({
    ip   = string
    name = string
  }))
}
