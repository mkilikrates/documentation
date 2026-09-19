variable "namespace" {
  description = "Kubernetes namespace for OpenBao"
  type        = string
  default     = "openbao-system"
}

variable "chart_version" {
  description = "Helm chart version for OpenBao"
  type        = string
  default     = "0.29.2"
}

variable "openbao_version" {
  description = "OpenBao container image tag"
  type        = string
  default     = "2.6.2"
}

variable "replicas" {
  description = "Number of OpenBao server replicas. Start at 1 to bootstrap the leader without a Raft join race (see openbao/openbao#2274), then raise to 3 after openbao-0 is initialised + unsealed."
  type        = number
  default     = 1
}

variable "storage_size" {
  description = "Persistent volume size for Raft storage"
  type        = string
  default     = "1Gi"
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = null
}

variable "enable_csi_provider" {
  description = "Enable the OpenBao CSI provider for Secrets Store CSI Driver"
  type        = bool
  default     = true
}

variable "enable_injector" {
  description = "Enable the OpenBao Agent injector (sidecar injection)"
  type        = bool
  default     = true
}

variable "expose_nodeport" {
  description = "Expose OpenBao UI via NodePort (for Kind/local development)"
  type        = bool
  default     = true
}

variable "nodeport" {
  description = "NodePort number for OpenBao UI"
  type        = number
  default     = 30820
}

variable "expose_gateway" {
  description = "Expose OpenBao via Gateway API HTTPRoute"
  type        = bool
  default     = true
}

variable "gateway_domain" {
  description = "Domain for the gateway HTTPRoute (e.g., 192.168.1.10.nip.io)"
  type        = string
  default     = "127.0.0.1.nip.io"
}
