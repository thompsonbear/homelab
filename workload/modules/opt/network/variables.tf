variable "app_name" {
  type        = string
}

variable "namespace" {
  type        = string
}

variable "public" {
  type        = bool
  description = "Whether the app should be exposed publicly"
}

variable "fqdns" {
  type = list(string)
  description = "List of fully qualified domain names to include in the certificate and listenerset"
}

variable "backend" {
  type = object({
    service = string
    port = number
  })
}
