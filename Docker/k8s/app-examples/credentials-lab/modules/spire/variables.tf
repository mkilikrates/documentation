variable "namespace" {
  description = "Kubernetes namespace for SPIRE"
  type        = string
  default     = "spire-system"
}

variable "trust_domain" {
  description = "SPIFFE trust domain"
  type        = string
  default     = "cluster.local"
}

variable "cluster_name" {
  description = "Kubernetes cluster name (must match Kind cluster)"
  type        = string
  default     = "kind-credentials-lab"
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = null # Latest
}

variable "spire_chart_version" {
  description = "SPIRE Helm chart version"
  type        = string
  default     = null # Latest
}
