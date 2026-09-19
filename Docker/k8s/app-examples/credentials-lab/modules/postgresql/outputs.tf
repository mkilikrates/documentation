output "service_host" {
  description = "In-cluster PostgreSQL host"
  value       = "postgres.${var.namespace}.svc.cluster.local"
}

output "port" {
  value = 5432
}

output "database" {
  value = var.database
}

output "admin_user" {
  value = var.admin_user
}
