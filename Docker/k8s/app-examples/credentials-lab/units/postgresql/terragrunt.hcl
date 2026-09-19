include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/postgresql"
}

# Vault provider — this module generates the postgres admin password and stores
# it in OpenBao (write-only). OpenBao (from Part 1) must be up and VAULT_ADDR/
# VAULT_TOKEN set before applying part3-infra. Token from VAULT_TOKEN env.
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
  namespace  = values.namespace
  admin_user = values.admin_user
  database   = values.database

  # Where the generated admin password is stored in OpenBao
  openbao_kv_mount = values.openbao_kv_mount
  openbao_kv_path  = values.openbao_kv_path
}
