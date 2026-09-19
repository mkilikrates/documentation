output "reader_service" {
  description = "Read-path (GET) service name"
  value       = kubernetes_service.api_reader.metadata[0].name
}

output "writer_service" {
  description = "Write-path (POST) service name"
  value       = kubernetes_service.api_writer.metadata[0].name
}

output "namespace" {
  value = var.namespace
}
