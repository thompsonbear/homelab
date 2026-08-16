variable "tag" {
  type = string
  description = "container image tag"
}

variable "replicas" {
  type = number
  default = 1
}
