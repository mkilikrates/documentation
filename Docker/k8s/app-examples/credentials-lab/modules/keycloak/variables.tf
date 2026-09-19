variable "namespace" {
  description = "Kubernetes namespace for Keycloak"
  type        = string
  default     = "keycloak"
}

variable "keycloak_version" {
  description = "Keycloak image tag (quay.io/keycloak/keycloak)"
  type        = string
  default     = "26.7.2"
}

variable "replicas" {
  description = "Number of Keycloak replicas (1 for the lab; 2+ for rolling updates)"
  type        = number
  default     = 1
}

variable "admin_user" {
  description = "Keycloak bootstrap admin username (temporary — removed after config)"
  type        = string
  default     = "bootstrap-admin"
}

# Where the generated bootstrap admin credential is stored in OpenBao (KV v2).
# This is the durable home; the value never touches Terraform state.
variable "openbao_kv_mount" {
  description = "OpenBao KV v2 mount for storing the Keycloak bootstrap admin credential"
  type        = string
  default     = "secret"
}

variable "openbao_kv_path" {
  description = "OpenBao KV v2 path for the Keycloak bootstrap admin credential"
  type        = string
  default     = "keycloak/bootstrap-admin"
}

variable "postgres_image" {
  description = "Postgres image for Keycloak's dedicated database"
  type        = string
  default     = "postgres:16-alpine"
}

variable "db_user" {
  description = "Keycloak database user"
  type        = string
  default     = "keycloak"
}

variable "db_name" {
  description = "Keycloak database name"
  type        = string
  default     = "keycloak"
}

variable "expose_gateway" {
  description = "Expose Keycloak via Gateway API HTTPRoute"
  type        = bool
  default     = true
}

variable "gateway_domain" {
  description = "Domain for the gateway HTTPRoute (e.g., 192.168.1.10.nip.io)"
  type        = string
  default     = "127.0.0.1.nip.io"
}
