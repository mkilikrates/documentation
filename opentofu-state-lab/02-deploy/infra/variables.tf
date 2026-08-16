variable "private_ip" {
  description = "Private IP of the host machine (used for nip.io DNS). Auto-detected if not set. Override with: export TF_VAR_private_ip=\"your.ip\""
  type        = string
  default     = ""
}

variable "nginx_fabric_version" {
  description = "Version of NGINX Gateway Fabric Helm chart to install"
  type        = string
  default     = "2.6.6"
}

variable "gateway_api_version" {
  description = "Version of Gateway API CRDs to install (must match nginx-fabric compatibility)"
  type        = string
  default     = "1.5.0"
}
