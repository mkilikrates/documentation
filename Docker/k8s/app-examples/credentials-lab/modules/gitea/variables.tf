variable "namespace" {
  description = "Kubernetes namespace for Gitea"
  type        = string
  default     = "gitea"
}

variable "chart_version" {
  description = "Helm chart version for Gitea"
  type        = string
  default     = null # Latest
}

variable "admin_username" {
  description = "Gitea admin username"
  type        = string
  default     = "gitea_admin"
}

# No admin_password variable: it's generated (ephemeral), stored write-only in a
# K8s Secret the chart references, and kept in OpenBao — never in state.

variable "admin_email" {
  description = "Gitea admin email"
  type        = string
  default     = "admin@credentials-lab.local"
}

variable "openbao_kv_mount" {
  description = "OpenBao KV v2 mount for storing the Gitea admin credential"
  type        = string
  default     = "secret"
}

variable "openbao_kv_path" {
  description = "OpenBao KV v2 path for the Gitea admin credential"
  type        = string
  default     = "gitea/admin"
}

variable "domain" {
  description = "Domain for Gitea (e.g., 192.168.1.10.nip.io)"
  type        = string
}
