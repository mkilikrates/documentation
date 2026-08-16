variable "private_ip" {
  description = "Private IP of the host machine (used for nip.io DNS). Auto-detected if empty."
  type        = string
  default     = ""
}

variable "nginx_fabric_version" {
  description = "Version of NGINX Gateway Fabric Helm chart"
  type        = string
  default     = "2.6.7"
}

variable "gateway_api_version" {
  description = "Version of Gateway API CRDs"
  type        = string
  default     = "1.5.0"
}

variable "node_selector" {
  description = "Node selector for NGINX Gateway Fabric pods"
  type        = map(string)
  default     = { "kubernetes.io/hostname" = "kind-control-plane" }
}

variable "service_type" {
  description = "Service type for NGINX Gateway Fabric"
  type        = string
  default     = "NodePort"
}

variable "http_node_port" {
  description = "NodePort for HTTP traffic"
  type        = number
  default     = 31437
}

variable "https_node_port" {
  description = "NodePort for HTTPS traffic"
  type        = number
  default     = 31438
}
