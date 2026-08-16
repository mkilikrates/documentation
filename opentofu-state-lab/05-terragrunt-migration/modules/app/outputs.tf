output "app_url" {
  description = "URL to access the application (host-based)"
  value       = "http://${var.app_name}.${local.private_ip}.nip.io/"
}

output "app_url_path" {
  description = "URL to access the application (path-based)"
  value       = "http://apps.${local.private_ip}.nip.io/${var.app_name}"
}

output "namespace" {
  description = "Kubernetes namespace for this app"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "deployment_name" {
  description = "Name of the Kubernetes deployment"
  value       = kubernetes_deployment.app.metadata[0].name
}

output "service_name" {
  description = "Name of the Kubernetes service"
  value       = kubernetes_service.app.metadata[0].name
}
