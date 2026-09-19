locals {
  name   = "credentials-lab"
  domain = "${get_env("MY_PRIVATE_IP", "127.0.0.1")}.nip.io"
  realm  = "credentials-lab"
}

# Part 4 (config): realm configuration + OpenBao OIDC auth.
#
# Configures Keycloak (realm, OIDC client, groups, users, TOTP) and OpenBao's
# OIDC auth method + human policies. Both need Keycloak already running:
# keycloak-config talks to Keycloak's admin API, and openbao-oidc validates the
# OIDC discovery URL at apply time. Same infra/config split as Parts 1 and 3.
#
# Prerequisites:
#   - stacks/part4-infra applied AND Keycloak Ready
#     (kubectl -n keycloak rollout status statefulset/keycloak)
#   - stacks/part1-config applied (kubernetes auth + base policies + KV)
#   - stacks/part3-infra + part3-config applied (database engine + roles:
#     the human-db-* policies grant access to database/creds/{readonly,
#     readwrite,migration}, which Part 3 creates)
#   - OpenBao initialized and unsealed; VAULT_ADDR and VAULT_TOKEN set
#
# Usage:
#   export MY_PRIVATE_IP="$(ip addr show $(route | grep '^default' | grep -o '[^ ]*$') | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
#   export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
#   export VAULT_TOKEN="<token>"
#   cd stacks/part4-config
#   terragrunt stack run apply

# Realm, OIDC client, groups, users, TOTP policy (needs Keycloak reachable)
unit "keycloak-config" {
  source                  = "../../units/keycloak-config"
  path                    = "keycloak-config"
  no_dot_terragrunt_stack = false
  values = {
    # Admin API through the gateway, same host tokens are issued for.
    keycloak_url       = "http://keycloak.${local.domain}"
    realm_name         = local.realm
    oidc_client_id     = "openbao"
    tf_admin_client_id = "terraform-admin"

    openbao_kv_mount            = "secret"
    openbao_kv_bootstrap_path   = "keycloak/bootstrap-admin"
    openbao_kv_oidc_client_path = "keycloak/openbao-oidc-client"
    openbao_kv_tf_admin_path    = "keycloak/terraform-admin"

    openbao_external_url = "http://openbao.${local.domain}"

    gitea_client_id              = "gitea"
    gitea_external_url           = "http://gitea.${local.domain}"
    openbao_kv_gitea_client_path = "keycloak/gitea-oidc-client"

    demo_users = ["engineer", "developer"]
  }
}

# OpenBao OIDC auth method, roles, and human policies (needs Keycloak realm
# issuer reachable for discovery, and the Part 3 database roles to exist)
unit "openbao-oidc" {
  source                  = "../../units/openbao-oidc"
  path                    = "openbao-oidc"
  no_dot_terragrunt_stack = false
  values = {
    oidc_issuer_url             = "http://keycloak.${local.domain}/realms/${local.realm}"
    oidc_client_id              = "openbao"
    openbao_kv_mount            = "secret"
    openbao_kv_oidc_client_path = "keycloak/openbao-oidc-client"
    openbao_external_url        = "http://openbao.${local.domain}"
  }
}
