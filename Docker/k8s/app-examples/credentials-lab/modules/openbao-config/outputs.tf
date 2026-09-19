output "kubernetes_auth_path" {
  description = "Path of the Kubernetes auth backend"
  value       = vault_auth_backend.kubernetes.path
}

output "base_policy_name" {
  description = "Name of the base policy"
  value       = vault_policy.base.name
}

output "admin_policy_name" {
  description = "Name of the admin policy"
  value       = vault_policy.admin.name
}
