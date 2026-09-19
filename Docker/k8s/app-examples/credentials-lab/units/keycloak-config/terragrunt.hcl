include "root" {
  path = find_in_parent_folders("root.hcl")
  # Deep merge so this unit's generate "provider_versions" block OVERRIDES the
  # one inherited from root (to add the keycloak provider) instead of colliding
  # with it ("generate blocks with the same name").
  merge_strategy = "deep"
  expose         = true
}

terraform {
  source = "../../../../modules/keycloak-config"
}

# Override root.hcl's generated versions.tf to ADD the keycloak provider.
# Using the SAME block name as the parent ("provider_versions") makes this
# child block override the one inherited via include (Terragrunt overrides
# parent generate blocks by name). The module must not declare its own
# required_providers block — Terraform allows only one per module.
generate "provider_versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.11.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.0"
    }
  }
}
EOF
}

# Vault provider — this unit reads the bootstrap admin credential from OpenBao
# (ephemerally) to configure the keycloak provider, and writes the OIDC/service-
# account client secrets back to OpenBao. Token from VAULT_TOKEN env.
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
# keycloak_auth_mode stays an env read: it flips across the bootstrap →
# service_account lifecycle (KC_AUTH_MODE), not per-environment.
inputs = {
  # Talk to Keycloak's admin API through the gateway, at the SAME host that
  # tokens are issued for — this keeps the OIDC issuer consistent for OpenBao.
  keycloak_url = values.keycloak_url

  # First apply uses the temporary bootstrap admin. After running
  # harden-remove-bootstrap-admin.sh, set KC_AUTH_MODE=service_account so future
  # applies authenticate as the terraform-admin service account.
  keycloak_auth_mode = get_env("KC_AUTH_MODE", "bootstrap")

  realm_name         = values.realm_name
  oidc_client_id     = values.oidc_client_id
  tf_admin_client_id = values.tf_admin_client_id

  # OpenBao KV locations — secrets live here, never in inputs/state
  openbao_kv_mount            = values.openbao_kv_mount
  openbao_kv_bootstrap_path   = values.openbao_kv_bootstrap_path
  openbao_kv_oidc_client_path = values.openbao_kv_oidc_client_path
  openbao_kv_tf_admin_path    = values.openbao_kv_tf_admin_path

  # OpenBao's external URL, for the UI OIDC callback redirect
  openbao_external_url = values.openbao_external_url

  # Gitea human SSO client (secret stored in OpenBao; configure-gitea-oidc.sh
  # reads it back to register Gitea's login source).
  gitea_client_id              = values.gitea_client_id
  gitea_external_url           = values.gitea_external_url
  openbao_kv_gitea_client_path = values.openbao_kv_gitea_client_path

  # Demo users — passwords set out-of-band (set-demo-user-passwords.sh).
  demo_users = values.demo_users
}
