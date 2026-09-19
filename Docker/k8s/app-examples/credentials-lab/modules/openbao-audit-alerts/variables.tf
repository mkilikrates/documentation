variable "folder_title" {
  description = "Grafana folder to hold the security alert rules"
  type        = string
  default     = "Security - Credentials"
}

variable "loki_datasource_uid" {
  description = "UID of the Loki datasource in Grafana (observability module provisions uid = \"loki\")"
  type        = string
  default     = "loki"
}

variable "openbao_namespace" {
  description = "Namespace label the OpenBao audit logs carry in Loki"
  type        = string
  default     = "openbao-system"
}

variable "canary_path" {
  description = "Audit request.path of the canary read (must match the openbao-canary module: <mount>/data/<canary_path>)"
  type        = string
  default     = "secret/data/database/production-admin"
}

variable "burst_threshold" {
  description = "Database credential issuances per minute above which the burst alert fires"
  type        = number
  default     = 10
}

variable "eval_interval_seconds" {
  description = "How often the rule group is evaluated"
  type        = number
  default     = 60
}

variable "runbook_url" {
  description = "Runbook link included in alert annotations"
  type        = string
  default     = "https://example.internal/runbooks/credential-leak"
}
