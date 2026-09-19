output "namespace" {
  description = "Namespace where Gitea is deployed"
  value       = kubernetes_namespace.gitea.metadata[0].name
}

output "internal_url" {
  description = "Internal URL for Gitea"
  value       = "http://gitea-http.${kubernetes_namespace.gitea.metadata[0].name}.svc.cluster.local:3000"
}

output "external_url" {
  description = "External URL for Gitea (via gateway)"
  value       = "http://gitea.${var.domain}"
}
