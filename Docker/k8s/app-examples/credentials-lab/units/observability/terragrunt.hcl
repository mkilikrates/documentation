include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/observability"
}

# Vault provider — this module generates the Grafana admin password and stores
# it in OpenBao (write-only), same as the postgresql module. OpenBao (Part 1)
# must be up and VAULT_ADDR/VAULT_TOKEN set before applying part5-infra.
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
# The install_* toggles let a stack reuse an existing Observability-series
# Loki/Alloy/Grafana instead of installing its own (default: install all).
inputs = {
  namespace        = values.namespace
  create_namespace = try(values.create_namespace, true)

  install_loki    = try(values.install_loki, true)
  install_alloy   = try(values.install_alloy, true)
  install_grafana = try(values.install_grafana, true)

  # Grafana admin credential: generated, write-only, stored in OpenBao.
  grafana_admin_secret_name = try(values.grafana_admin_secret_name, "grafana-admin")
  store_admin_in_openbao    = try(values.store_admin_in_openbao, true)
  openbao_kv_mount          = values.openbao_kv_mount
  openbao_kv_path           = values.openbao_kv_path

  expose_gateway = try(values.expose_gateway, true)
  gateway_domain = values.gateway_domain
}
