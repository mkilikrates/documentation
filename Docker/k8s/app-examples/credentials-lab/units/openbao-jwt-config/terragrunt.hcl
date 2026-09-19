include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/openbao-jwt-config"
}

# Wait for Gitea: OpenBao validates the jwt-gitea OIDC discovery URL live when
# the backend is created, so Gitea must exist and be serving before this unit
# runs. Same pattern as openbao-oidc waiting on keycloak-config. The gitea unit's
# helm_release uses wait=true, so once its outputs resolve the pods are up.
dependency "gitea" {
  config_path = "../gitea"

  mock_outputs = {
    external_url = "http://gitea.127.0.0.1.nip.io"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

# Vault provider — connects via the gateway (same as part1-config)
generate "provider_vault" {
  path      = "provider_vault.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "vault" {
  address = "${get_env("VAULT_ADDR", "http://openbao.127.0.0.1.nip.io")}"
}
EOF
}

# Reusable unit — per-deployment config via `values`, except gitea_oidc_url,
# which is WIRING taken from the gitea unit's output (see dependency above).
inputs = {
  kubernetes_auth_path = try(values.kubernetes_auth_path, "kubernetes")
  enable_gitea_jwt     = try(values.enable_gitea_jwt, true)

  # The issuer MUST match, byte for byte, the "issuer" advertised in Gitea's
  # discovery document — Gitea's ROOT_URL with NO trailing slash. The gitea
  # unit's external_url output is exactly that, so use it verbatim (do NOT append
  # a "/", or OpenBao's discovery check fails with "error checking oidc discovery
  # URL"). OpenBao appends /.well-known/openid-configuration.
  gitea_oidc_url = dependency.gitea.outputs.external_url
}
