variable "chart_tag" {
  type        = string
  description = "The chart tag to use for the cnpg-operator"
}

variable "image_tag" {
  type        = string
  description = "The image tag to use for the cnpg-operator"
}

variable "replicas" {
  type        = number
  description = "The number of replicas to use for the cnpg-operator"
  default     = 1
}
