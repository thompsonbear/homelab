variable "realm_id" {
  type        = string
  description = "The ID of the realm to create the client in"
}

variable "namespace" {
  type        = string
}

variable "client_id" {
  type        = string
  description = "The ID of the client to create"
}

variable "redirect_uris" {
  type        = list(string)
  description = "The redirect URIs for the client"
}

variable "logout_uris" {
  type        = list(string)
  description = "The logout URIs for the client"
}

variable "prefix_role_claim" {
  type        = bool
  description = "Whether to prefix role claims with the client name"
}

variable "multivalued_role_claim" {
  type        = bool
  description = "Whether to use multivalued claim for role/roles claim"
}

variable "client_roles" {
  type        = list(string)
  description = "The roles to create along with the client"
}
