variable "namespace" {
  description = "Namespace for the demo app (shared with PostgreSQL)"
  type        = string
  default     = "database-demo"
}

variable "vault_internal_addr" {
  description = "In-cluster OpenBao address (active service)"
  type        = string
  default     = "http://openbao-active.openbao-system.svc.cluster.local:8200"
}

variable "db_host" {
  description = "PostgreSQL host"
  type        = string
  default     = "postgres.database-demo.svc.cluster.local"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "app"
}

variable "replicas" {
  description = "Number of api-server replicas (each gets its own DB user)"
  type        = number
  default     = 3
}

variable "expose_gateway" {
  description = "Expose the api-server via Gateway API HTTPRoute (for external curl testing)"
  type        = bool
  default     = true
}

variable "gateway_domain" {
  description = "Domain for the gateway HTTPRoute (e.g., 192.168.1.10.nip.io)"
  type        = string
  default     = "127.0.0.1.nip.io"
}
