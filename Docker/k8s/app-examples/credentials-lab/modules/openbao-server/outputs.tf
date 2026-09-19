output "namespace" {
  description = "Namespace where OpenBao is deployed"
  value       = kubernetes_namespace.openbao.metadata[0].name
}

output "service_name" {
  description = "OpenBao service name for internal access"
  value       = "openbao"
}

output "internal_url" {
  description = "Internal URL for OpenBao API"
  value       = "http://openbao.${kubernetes_namespace.openbao.metadata[0].name}.svc.cluster.local:8200"
}

output "helm_release_name" {
  description = "Helm release name"
  value       = helm_release.openbao.name
}
