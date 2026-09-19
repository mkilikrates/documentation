output "namespace" {
  description = "Namespace where SPIRE is deployed"
  value       = kubernetes_namespace.spire.metadata[0].name
}

output "trust_domain" {
  description = "SPIFFE trust domain"
  value       = var.trust_domain
}

output "cluster_name" {
  description = "Cluster name used in SPIRE config"
  value       = var.cluster_name
}
