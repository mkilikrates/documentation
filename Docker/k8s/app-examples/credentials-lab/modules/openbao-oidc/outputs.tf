output "auth_path" {
  description = "Mount path of the OIDC auth method"
  value       = vault_jwt_auth_backend.oidc.path
}

output "roles" {
  description = "OIDC role names, keyed by persona"
  value = {
    developer         = vault_jwt_auth_backend_role.developer.role_name
    platform_engineer = vault_jwt_auth_backend_role.platform_engineer.role_name
    oncall_breakglass = vault_jwt_auth_backend_role.oncall.role_name
  }
}
