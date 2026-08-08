variable "environment" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "network" {
  type = object({
    dns_server_list   = list(string)
    dns_search_domain = string
  })
  description = "the deployment network details"
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
