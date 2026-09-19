variable "namespace" {
  description = "Namespace to deploy PostgreSQL into (created by this module)"
  type        = string
  default     = "database-demo"
}

variable "admin_user" {
  description = "PostgreSQL admin/root user (OpenBao rotates this in production)"
  type        = string
  default     = "postgres"
}

# NOTE: no admin_password variable. The password is generated (ephemeral),
# written to the K8s Secret write-only, and stored in OpenBao — never in state.

variable "openbao_kv_mount" {
  description = "OpenBao KV v2 mount for storing the postgres admin credential"
  type        = string
  default     = "secret"
}

variable "openbao_kv_path" {
  description = "OpenBao KV v2 path for the postgres admin credential"
  type        = string
  default     = "postgres/admin"
}

variable "database" {
  description = "Application database name"
  type        = string
  default     = "app"
}
