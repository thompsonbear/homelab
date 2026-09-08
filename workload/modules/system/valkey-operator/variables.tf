variable "tag" {
  type        = string
  description = "The version tag to use for the valkey-operator"
}

variable "replicas" {
  type        = number
  description = "The number of replicas to use for the valkey-operator"
  default     = 1
}
