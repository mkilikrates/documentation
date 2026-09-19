include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/openbao-oidc"
}

# Wait for keycloak-config: the realm must exist before OpenBao can validate
# the OIDC discovery URL. Without this, the two units run in parallel and
# openbao-oidc fails with "error checking oidc discovery URL" because the realm
# isn't created yet. (Path is relative to the generated .terragrunt-stack dir.)
dependency "keycloak_config" {
  config_path = "../keycloak-config"

  # Allow plan/validate to run before keycloak-config has state/outputs.
  mock_outputs = {
    realm       = "credentials-lab"
    issuer_url  = "http://keycloak.127.0.0.1.nip.io/realms/credentials-lab"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

# Vault provider — connects via the gateway (same as part1-config / openbao-jwt-config)
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
  # Must match Keycloak's realm issuer exactly (the fixed KC_HOSTNAME + realm).
  oidc_issuer_url = values.oidc_issuer_url
  oidc_client_id  = values.oidc_client_id

  # The OIDC client secret is read from OpenBao KV ephemerally (written by
  # keycloak-config) — never passed as a plaintext input.
  openbao_kv_mount            = values.openbao_kv_mount
  openbao_kv_oidc_client_path = values.openbao_kv_oidc_client_path

  openbao_external_url = values.openbao_external_url
}
