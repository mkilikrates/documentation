# OpenBao OIDC auth (Part 4) — human authentication federated to Keycloak.
#
# Uses the vault provider (root.hcl generates no provider block for it, so it
# reads VAULT_ADDR / VAULT_TOKEN from the environment, same as part1-config and
# part3-config).
#
# The three roles map Keycloak groups -> OpenBao policies:
#   developers         -> read-only DB
#   platform-engineers -> read-write DB
#   oncall             -> break-glass (DDL) with the shortest TTL

# Read the OIDC client credentials from OpenBao ephemerally — keycloak-config
# generated the client secret and stored it here; we read it just long enough to
# configure the auth method. Never written to state or plan.
ephemeral "vault_kv_secret_v2" "oidc_client" {
  mount = var.openbao_kv_mount
  name  = var.openbao_kv_oidc_client_path
}

resource "vault_jwt_auth_backend" "oidc" {
  path               = "oidc"
  type               = "oidc"
  description        = "OIDC authentication via Keycloak"
  oidc_discovery_url = var.oidc_issuer_url
  # client_id is not secret — plain var. (Ephemeral values can only feed
  # ephemeral/write-only attributes, so only the secret reads from OpenBao.)
  oidc_client_id = var.oidc_client_id

  # Write-only: the client secret is consumed by OpenBao but not stored in
  # Terraform state. The value comes from OpenBao (ephemeral read above).
  oidc_client_secret_wo         = ephemeral.vault_kv_secret_v2.oidc_client.data["client_secret"]
  oidc_client_secret_wo_version = 1

  bound_issuer = var.oidc_issuer_url
  default_role = "developer"

  tune {
    default_lease_ttl = "1h"
    max_lease_ttl     = "2h"
    token_type        = "default-service"
  }
}

locals {
  redirect_uris = [
    "http://localhost:8250/oidc/callback",
    "${var.openbao_external_url}/ui/vault/auth/oidc/oidc/callback",
  ]
}

# Role: developers — read-only database access
resource "vault_jwt_auth_backend_role" "developer" {
  backend   = vault_jwt_auth_backend.oidc.path
  role_name = "developer"
  role_type = "oidc"

  allowed_redirect_uris = local.redirect_uris
  oidc_scopes           = ["openid", "profile", "email"]
  user_claim            = "sub"
  groups_claim          = "groups"

  # Keycloak ID tokens carry aud = client_id. OpenBao/Vault 1.17+ REQUIRES a
  # matching bound_audiences when the token has an aud claim, or login fails.
  bound_audiences = [var.oidc_client_id]

  # Match the group by exact string (any-match against the multi-valued claim).
  bound_claims_type = "string"
  bound_claims = {
    groups = "developers"
  }

  claim_mappings = {
    preferred_username = "username"
    email              = "email"
  }

  token_policies = ["base", "human-db-readonly"]
  token_ttl      = 1800 # 30 minutes
  token_max_ttl  = 3600 # 1 hour
}

# Role: platform engineers — read-write database access
resource "vault_jwt_auth_backend_role" "platform_engineer" {
  backend   = vault_jwt_auth_backend.oidc.path
  role_name = "platform-engineer"
  role_type = "oidc"

  allowed_redirect_uris = local.redirect_uris
  oidc_scopes           = ["openid", "profile", "email"]
  user_claim            = "sub"
  groups_claim          = "groups"

  bound_audiences = [var.oidc_client_id]

  bound_claims_type = "string"
  bound_claims = {
    groups = "platform-engineers"
  }

  claim_mappings = {
    preferred_username = "username"
    email              = "email"
  }

  token_policies = ["base", "human-db-readwrite"]
  token_ttl      = 1800 # 30 minutes
  token_max_ttl  = 3600 # 1 hour
}

# Role: on-call break-glass — elevated (DDL) access, shortest TTL
resource "vault_jwt_auth_backend_role" "oncall" {
  backend   = vault_jwt_auth_backend.oidc.path
  role_name = "oncall-breakglass"
  role_type = "oidc"

  allowed_redirect_uris = local.redirect_uris
  oidc_scopes           = ["openid", "profile", "email"]
  user_claim            = "sub"
  groups_claim          = "groups"

  bound_audiences = [var.oidc_client_id]

  bound_claims_type = "string"
  bound_claims = {
    groups = "oncall"
  }

  claim_mappings = {
    preferred_username = "username"
    email              = "email"
  }

  token_policies = ["base", "human-db-readwrite", "human-db-migration", "breakglass-audit"]
  token_ttl      = 900  # 15 minutes — emergencies should be short
  token_max_ttl  = 1800 # 30 minutes absolute maximum
}
