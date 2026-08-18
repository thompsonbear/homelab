variable "environment" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "dns_servers" {
  type        = list(string)
  description = "The DNS servers for the network (e.g. [\"8.8.8.8\"])"
}

variable "dns_search_domain" {
  type        = string
  description = "The DNS search domain for the network (e.g. example.local)"
}

variable "kube_vip" {
  type = string
}

variable "control_plane_nodes" {
  type = map(object({
    ip = string
  }))
}

variable "worker_nodes" {
  type = map(object({
    ip = string
  }))
}
