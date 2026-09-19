include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/gitea"
}

# Vault provider — the module generates the Gitea admin password and stores it
# in OpenBao (write-only). Requires VAULT_ADDR/VAULT_TOKEN (OpenBao from Part 1).
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
  admin_username = values.admin_username
  admin_email    = values.admin_email
  domain         = values.domain

  # Generated admin password is stored in OpenBao here
  openbao_kv_mount = values.openbao_kv_mount
  openbao_kv_path  = values.openbao_kv_path
}
