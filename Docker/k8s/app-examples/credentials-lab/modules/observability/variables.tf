variable "namespace" {
  description = "Namespace for the observability stack"
  type        = string
  default     = "monitoring"
}

variable "create_namespace" {
  description = "Create the monitoring namespace. Set false if it already exists (e.g. from the Observability series)."
  type        = bool
  default     = true
}

# --- Component toggles: reuse an existing stack by turning pieces off ---
variable "install_loki" {
  description = "Install Loki. Set false to reuse an existing Loki in the cluster."
  type        = bool
  default     = true
}

variable "install_alloy" {
  description = "Install Alloy. Set false to reuse an existing Alloy/Promtail collector."
  type        = bool
  default     = true
}

variable "install_grafana" {
  description = "Install Grafana. Set false to reuse an existing Grafana."
  type        = bool
  default     = true
}

# --- Chart versions (pin for reproducibility) ---
variable "loki_chart_version" {
  description = "grafana/loki chart version"
  type        = string
  default     = "6.24.0"
}

variable "alloy_chart_version" {
  description = "grafana/alloy chart version"
  type        = string
  default     = "0.10.1"
}

variable "grafana_chart_version" {
  description = "grafana/grafana chart version"
  type        = string
  default     = "8.5.1"
}

# --- Grafana admin credential (generated, write-only, stored in OpenBao) ---
variable "grafana_admin_secret_name" {
  description = "Name of the K8s Secret holding the generated Grafana admin credential"
  type        = string
  default     = "grafana-admin"
}

variable "store_admin_in_openbao" {
  description = "Also store the generated Grafana admin credential in OpenBao KV"
  type        = bool
  default     = true
}

variable "openbao_kv_mount" {
  description = "OpenBao KV v2 mount to store the Grafana admin credential"
  type        = string
  default     = "secret"
}

variable "openbao_kv_path" {
  description = "OpenBao KV path for the Grafana admin credential"
  type        = string
  default     = "grafana/admin"
}

# --- Gateway exposure ---
variable "expose_gateway" {
  description = "Expose Grafana via a Gateway API HTTPRoute"
  type        = bool
  default     = true
}

variable "gateway_domain" {
  description = "Base domain for the Grafana HTTPRoute hostname (grafana.<domain>)"
  type        = string
  default     = "127.0.0.1.nip.io"
}
