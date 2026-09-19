output "mount_path" {
  description = "Path where the database secrets engine is mounted"
  value       = vault_mount.database.path
}

output "roles" {
  description = "Available database roles"
  value       = ["readonly", "readwrite", "migration"]
}
