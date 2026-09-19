output "namespace" {
  description = "Namespace the observability stack runs in"
  value       = local.namespace
}

output "loki_url" {
  description = "In-cluster Loki base URL (query + push)"
  value       = "http://loki.${local.namespace}:3100"
}

output "grafana_internal_url" {
  description = "In-cluster Grafana URL"
  value       = "http://grafana.${local.namespace}:80"
}

output "grafana_admin_secret_name" {
  description = "K8s Secret holding the generated Grafana admin credential"
  value       = var.grafana_admin_secret_name
}

output "grafana_admin_openbao_path" {
  description = "OpenBao KV path where the Grafana admin credential is stored"
  value       = var.store_admin_in_openbao ? "${var.openbao_kv_mount}/${var.openbao_kv_path}" : null
}
