variable "namespace" {
  description = "Namespace for the service-to-service demo app"
  type        = string
  default     = "credentials-demo"
}

variable "vault_internal_addr" {
  description = "In-cluster OpenBao address (active service)"
  type        = string
  default     = "http://openbao-active.openbao-system.svc.cluster.local:8200"
}

variable "trust_domain" {
  description = "SPIFFE trust domain (must match the SPIRE deployment)"
  type        = string
  default     = "cluster.local"
}

variable "spiffe_helper_image" {
  description = "spiffe-helper image that fetches/rotates the SVID from the Workload API"
  type        = string
  default     = "ghcr.io/spiffe/spiffe-helper:0.11.0"
}
