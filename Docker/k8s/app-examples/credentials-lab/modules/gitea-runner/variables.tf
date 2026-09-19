variable "namespace" {
  description = "Namespace to deploy the runner into (same as Gitea)"
  type        = string
  default     = "gitea"
}

variable "gitea_internal_url" {
  description = "In-cluster Gitea URL the runner registers against"
  type        = string
  default     = "http://gitea-http.gitea.svc.cluster.local:3000"
}

variable "token_secret_name" {
  description = "K8s Secret holding the runner registration token (populated by register-gitea-runner.sh)"
  type        = string
  default     = "gitea-runner-token"
}

variable "runner_image" {
  description = "act_runner image (pinned)"
  type        = string
  default     = "gitea/act_runner:0.2.11"
}

variable "dind_image" {
  description = "Docker-in-Docker sidecar image (pinned)"
  type        = string
  default     = "docker:27-dind"
}

variable "default_job_image" {
  description = "Container image used for jobs labelled ubuntu-latest / node"
  type        = string
  default     = "node:20-bookworm"
}

variable "runner_capacity" {
  description = "Number of concurrent jobs the runner accepts"
  type        = number
  default     = 1
}
