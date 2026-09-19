variable "kubernetes_host" {
  description = "Kubernetes API server URL"
  type        = string
  default     = "https://kubernetes.default.svc.cluster.local:443"
}

variable "enable_kv_engine" {
  description = "Enable KV v2 engine (for static secrets during migration)"
  type        = bool
  default     = true
}
