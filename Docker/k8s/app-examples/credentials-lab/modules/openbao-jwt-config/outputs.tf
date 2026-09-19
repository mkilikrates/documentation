output "service_token_role" {
  description = "Name of the identity token role for service-to-service auth"
  value       = vault_identity_oidc_role.service_token.name
}

output "frontend_role" {
  description = "Kubernetes auth role for the frontend service"
  value       = vault_kubernetes_auth_backend_role.frontend.role_name
}

output "backend_role" {
  description = "Kubernetes auth role for the backend service"
  value       = vault_kubernetes_auth_backend_role.backend.role_name
}

output "pipeline_policy" {
  description = "Policy name for CI/CD pipelines"
  value       = vault_policy.pipeline_deploy.name
}
