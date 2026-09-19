include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/openbao-config"
}

# OpenBao is exposed via Gateway API at http://openbao.<MY_PRIVATE_IP>.nip.io
# VAULT_ADDR and VAULT_TOKEN must be set before running this unit.
#
# Usage:
#   export MY_PRIVATE_IP="$(ip addr show $(route | grep '^default' | grep -o '[^ ]*$') | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
#   export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
#   export VAULT_TOKEN="<root-token-from-init>"
#   terragrunt stack run apply (from stacks/part1-config)

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
  kubernetes_host  = values.kubernetes_host
  enable_kv_engine = try(values.enable_kv_engine, true)
}
