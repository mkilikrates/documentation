include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/keycloak"
}

# Vault provider — the module writes the generated bootstrap admin credential to
# OpenBao KV (write-only). Connects via the gateway, token from VAULT_TOKEN env
# (same pattern as part1-config / openbao-oidc).
generate "provider_vault" {
  path      = "provider_vault.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "vault" {
  address = "${get_env("VAULT_ADDR", "http://openbao.127.0.0.1.nip.io")}"
}
EOF
}

# Reusable unit — per-deployment config comes from the stack via `values`.
inputs = {
  namespace      = values.namespace
  admin_user     = values.admin_user
  expose_gateway = try(values.expose_gateway, true)
  gateway_domain = values.gateway_domain

  # OpenBao KV location for the generated bootstrap admin credential
  openbao_kv_mount = values.openbao_kv_mount
  openbao_kv_path  = values.openbao_kv_path
}
