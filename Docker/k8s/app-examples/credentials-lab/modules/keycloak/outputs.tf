output "namespace" {
  description = "Namespace where Keycloak is deployed"
  value       = kubernetes_namespace.keycloak.metadata[0].name
}

output "internal_url" {
  description = "In-cluster URL for Keycloak"
  value       = "http://keycloak.${kubernetes_namespace.keycloak.metadata[0].name}.svc.cluster.local:8080"
}

output "external_url" {
  description = "External URL for Keycloak (via gateway)"
  value       = "http://keycloak.${var.gateway_domain}"
}
