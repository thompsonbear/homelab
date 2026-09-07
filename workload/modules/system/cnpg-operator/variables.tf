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

variable "pg_images" {
  type = list(object({
    major = number
    image = string
    extensions = optional(list(object({
      name = string
      image = object({ reference = string})
      dynamic_library_path = optional(list(string))
      extension_control_path = optional(list(string))
    })))
  }))
  description = "The PostgreSQL/extension images to use for the global image catalog"
}
