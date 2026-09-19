include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/openbao-canary"
}

# Vault provider — plants the honey-token and the trap policy. Token from
# VAULT_TOKEN env. (The canary is intentionally plaintext — see the module.)
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
  kv_mount           = try(values.kv_mount, "secret")
  canary_path        = values.canary_path
  canary_policy_name = try(values.canary_policy_name, "canary-trap")
}
