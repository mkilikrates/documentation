variable "kubernetes_auth_path" {
  description = "Path of the Kubernetes auth backend"
  type        = string
  default     = "kubernetes"
}

variable "enable_gitea_jwt" {
  description = "Enable JWT auth method for Gitea Actions OIDC"
  type        = bool
  default     = false
}

variable "gitea_oidc_url" {
  description = "Gitea OIDC issuer/discovery base URL (must end with a trailing slash; OpenBao appends .well-known/openid-configuration)"
  type        = string
  default     = ""
}

variable "gitea_discovery_max_wait_seconds" {
  description = "Total time budget to wait for Gitea's OIDC discovery URL to be ready (exponential backoff 5s..60s per attempt). Caps at 5 minutes by default; the gate exits as soon as discovery is ready with a matching issuer."
  type        = number
  default     = 300
}

variable "gitea_discovery_settle_seconds" {
  description = "Extra settle time to wait after discovery becomes ready, before configuring the OpenBao jwt-gitea backend"
  type        = number
  default     = 30
}
