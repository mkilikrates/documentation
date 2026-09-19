include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/openbao-database"
}

# Vault provider — connects via the gateway (same as part1-config / jwt-config)
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
  kubernetes_auth_path = try(values.kubernetes_auth_path, "kubernetes")
  namespace            = values.namespace
  postgres_host        = values.postgres_host
  postgres_port        = try(values.postgres_port, 5432)
  postgres_db          = values.postgres_db
  postgres_admin_user  = values.postgres_admin_user

  # Admin password is read from OpenBao KV ephemerally (written by postgresql)
  openbao_kv_mount = values.openbao_kv_mount
  openbao_kv_path  = values.openbao_kv_path

  default_ttl = try(values.default_ttl, 1800)
  max_ttl     = try(values.max_ttl, 3600)
}
