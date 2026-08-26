variable "app_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "base_public_domain" {
  type = string
}

variable "base_private_domain" {
  type = string
}

variable "public_gateway_ip" {
  type = string
}

variable "private_gateway_ip" {
  type = string
}

variable "dns" {
  type = object({
    labels = list(string)
    public = bool
  })
}

variable "backend" {
  type = object({
    service = string
    port    = number
  })
}
