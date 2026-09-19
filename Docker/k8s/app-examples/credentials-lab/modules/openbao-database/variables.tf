variable "kubernetes_auth_path" {
  description = "Path of the Kubernetes auth backend"
  type        = string
  default     = "kubernetes"
}

variable "namespace" {
  description = "Namespace of the demo app service accounts"
  type        = string
  default     = "database-demo"
}

variable "postgres_host" {
  description = "PostgreSQL host"
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "app"
}

variable "postgres_admin_user" {
  description = "PostgreSQL admin user OpenBao uses to create dynamic roles (not secret; also used as REASSIGN OWNED target)"
  type        = string
  default     = "postgres"
}

# The admin PASSWORD is not a variable — it's read from OpenBao KV ephemerally
# (written by the postgresql module) into the connection's write-only password.
variable "openbao_kv_mount" {
  description = "OpenBao KV v2 mount holding the postgres admin credential"
  type        = string
  default     = "secret"
}

variable "openbao_kv_path" {
  description = "OpenBao KV v2 path holding the postgres admin credential"
  type        = string
  default     = "postgres/admin"
}

variable "default_ttl" {
  description = "Default lease TTL for dynamic credentials (seconds)"
  type        = number
  default     = 1800 # 30 minutes
}

variable "max_ttl" {
  description = "Maximum lease TTL for dynamic credentials (seconds)"
  type        = number
  default     = 3600 # 1 hour
}
