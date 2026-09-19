variable "kv_mount" {
  description = "OpenBao KV v2 mount to plant the canary in"
  type        = string
  default     = "secret"
}

variable "canary_path" {
  description = "KV path for the honey-token. Choose something a probe would find tempting."
  type        = string
  default     = "database/production-admin"
}

variable "canary_policy_name" {
  description = "Name of the trap policy (attached to no legitimate role)"
  type        = string
  default     = "canary-trap"
}
