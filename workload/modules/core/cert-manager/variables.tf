variable "tag" {
  type = string
  description = "container image tag"
}

variable "replicas" {
  type = number
  default = 1
}

variable "acme_email" {
  type = string
  description = "email used for ACME account registration"
}

variable "base_public_domain" {
  type = string
  description = "base public domain"
}

variable "environment" {
  type = string
  description = "environment"
}

variable "cloudflare_token" {
  type = string
  description = "Cloudflare DNS API token"
  sensitive = true
}
