# Keycloak realm configuration (Part 4) — realm, OIDC client, groups, users,
# TOTP policy, and the group-membership mapper. All declared as code so the
# whole IdP setup is reproducible (and survives Keycloak's ephemeral storage).

# NOTE: the keycloak provider is declared in the generated versions.tf (the
# keycloak-config unit overrides root.hcl's provider_versions generation to add
# it). We intentionally do NOT put a second terraform{} required_providers block
# here — Terraform allows only one per module.

# The realm — one tenant for the lab.
resource "keycloak_realm" "lab" {
  realm   = var.realm_name
  enabled = true

  # Enforce a reasonable password policy for human accounts.
  password_policy = "length(12) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1)"

  # TOTP (time-based OTP) policy — the second factor.
  otp_policy {
    type              = "totp"
    algorithm         = "HmacSHA1"
    digits            = 6
    period            = 30
    look_ahead_window = 1
  }
}

# --- OIDC client for OpenBao ---

# Generate the OIDC client secret; never stored in state (ephemeral).
ephemeral "random_password" "openbao_client_secret" {
  length  = 32
  special = false
}

locals {
  openbao_client_secret_revision = 1
}

resource "keycloak_openid_client" "openbao" {
  realm_id  = keycloak_realm.lab.id
  client_id = var.oidc_client_id
  name      = "OpenBao Secrets Manager"
  enabled   = true

  access_type = "CONFIDENTIAL"

  # Write-only secret: the provider sets it in Keycloak but Terraform does not
  # persist it in state. The value lives in OpenBao (written below) and is read
  # ephemerally by the openbao-oidc unit.
  client_secret_wo         = ephemeral.random_password.openbao_client_secret.result
  client_secret_wo_version = local.openbao_client_secret_revision

  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  # Callback URLs: the bao CLI listens on localhost:8250; the UI callback goes
  # through the external Keycloak/OpenBao host.
  valid_redirect_uris = [
    "http://localhost:8250/oidc/callback",
    "${var.openbao_external_url}/ui/vault/auth/oidc/oidc/callback",
  ]
}

# Store the OpenBao OIDC client secret in OpenBao KV (write-only — not in state).
# The openbao-oidc unit reads it back ephemerally to configure the OIDC auth
# method, so the shared secret never appears in any state file or in git.
resource "vault_kv_secret_v2" "openbao_oidc_client" {
  mount = var.openbao_kv_mount
  name  = var.openbao_kv_oidc_client_path

  data_json_wo = jsonencode({
    client_id     = var.oidc_client_id
    client_secret = ephemeral.random_password.openbao_client_secret.result
  })
  data_json_wo_version = local.openbao_client_secret_revision
}

# Emit the user's groups into the ID token as a top-level "groups" claim so
# OpenBao can match on it. full_path=false gives plain names (e.g.
# "platform-engineers"), which is what the OpenBao roles bind against.
resource "keycloak_openid_group_membership_protocol_mapper" "groups" {
  realm_id   = keycloak_realm.lab.id
  client_id  = keycloak_openid_client.openbao.id
  name       = "group-membership"
  claim_name = "groups"
  full_path  = false

  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# --- OIDC client for Gitea (human SSO login) ---
#
# Lets Keycloak users log into Gitea's web UI via "Log in with Keycloak", using
# the SAME realm and users as the OpenBao human-auth flow. Same hygiene as the
# OpenBao client: the secret is generated ephemerally, set write-only (never in
# state), and stored in OpenBao. The Gitea login source is wired up at runtime
# by configure-gitea-oidc.sh (which reads this secret back from OpenBao) — Gitea
# has no Terraform provider for OAuth2 login sources.

ephemeral "random_password" "gitea_client_secret" {
  length  = 32
  special = false
}

locals {
  gitea_client_secret_revision = 1
}

resource "keycloak_openid_client" "gitea" {
  realm_id  = keycloak_realm.lab.id
  client_id = var.gitea_client_id
  name      = "Gitea"
  enabled   = true

  access_type = "CONFIDENTIAL"

  client_secret_wo         = ephemeral.random_password.gitea_client_secret.result
  client_secret_wo_version = local.gitea_client_secret_revision

  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  # Gitea's OAuth2 login-source callback. The path segment ("keycloak") must
  # match the login-source NAME registered by configure-gitea-oidc.sh.
  valid_redirect_uris = [
    "${var.gitea_external_url}/user/oauth2/keycloak/callback",
  ]
}

# A realm-level "groups" CLIENT SCOPE. Gitea's OIDC login source requests a
# "groups" scope (it adds it to the authorize request), and Keycloak rejects any
# scope it doesn't recognize with "Invalid scopes". Registering it as a real
# client scope makes the request valid AND carries the group-membership claim.
resource "keycloak_openid_client_scope" "groups" {
  realm_id               = keycloak_realm.lab.id
  name                   = "groups"
  description            = "Group memberships (for app RBAC, e.g. Gitea teams)"
  include_in_token_scope = true
}

# The group-membership mapper lives on the scope (not the client), so it applies
# wherever the scope is assigned. full_path=false → plain names ("developers").
resource "keycloak_openid_group_membership_protocol_mapper" "gitea_groups" {
  realm_id        = keycloak_realm.lab.id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "group-membership"
  claim_name      = "groups"
  full_path       = false

  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# Attach the "groups" scope to the gitea client as a DEFAULT scope, so it's
# always included and recognized when Gitea requests it.
#
# NOTE: this resource REPLACES the client's entire default-scope list, so it
# must contain only scopes that exist as REGISTERED client scopes. "openid" is
# NOT a client scope — it's the implicit OIDC marker Keycloak adds itself — so
# listing it here fails with "scope openid does not exist". We list Keycloak's
# built-in defaults (profile, email, roles, web-origins, acr) plus our groups.
resource "keycloak_openid_client_default_scopes" "gitea" {
  realm_id  = keycloak_realm.lab.id
  client_id = keycloak_openid_client.gitea.id

  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    "acr",
    keycloak_openid_client_scope.groups.name,
  ]
}

# Store the Gitea OIDC client secret in OpenBao (write-only — not in state).
# configure-gitea-oidc.sh reads it back to register the Gitea login source.
resource "vault_kv_secret_v2" "gitea_oidc_client" {
  mount = var.openbao_kv_mount
  name  = var.openbao_kv_gitea_client_path

  data_json_wo = jsonencode({
    client_id     = var.gitea_client_id
    client_secret = ephemeral.random_password.gitea_client_secret.result
  })
  data_json_wo_version = local.gitea_client_secret_revision
}

# --- Groups (mapped to OpenBao policies in the openbao-oidc module) ---

resource "keycloak_group" "platform_engineers" {
  realm_id = keycloak_realm.lab.id
  name     = "platform-engineers"
}

resource "keycloak_group" "developers" {
  realm_id = keycloak_realm.lab.id
  name     = "developers"
}

resource "keycloak_group" "oncall" {
  realm_id = keycloak_realm.lab.id
  name     = "oncall"
}

# --- Sample users ---
#
# NOTE: we deliberately do NOT set initial_password here. The keycloak provider
# has no write-only password argument, so any password set on the resource would
# be persisted in Terraform state. Instead the users are created WITHOUT a
# password and with UPDATE_PASSWORD required; a temporary password is generated
# and set out-of-band (stored in OpenBao) by set-demo-user-passwords.sh. This
# keeps state free of any human credential — and mirrors real practice, where
# users are federated/reset rather than having passwords baked into IaC.

resource "keycloak_user" "engineer" {
  realm_id = keycloak_realm.lab.id
  username = "engineer"
  enabled  = true

  email          = "engineer@example.com"
  email_verified = true
  first_name     = "Platform"
  last_name      = "Engineer"

  # First login must set a password and enroll TOTP. The realm browser flow
  # then requires the OTP on every subsequent login.
  required_actions = ["UPDATE_PASSWORD", "CONFIGURE_TOTP"]
}

resource "keycloak_user_groups" "engineer_groups" {
  realm_id = keycloak_realm.lab.id
  user_id  = keycloak_user.engineer.id
  group_ids = [
    keycloak_group.platform_engineers.id,
    keycloak_group.oncall.id,
  ]
}

resource "keycloak_user" "developer" {
  realm_id = keycloak_realm.lab.id
  username = "developer"
  enabled  = true

  email          = "developer@example.com"
  email_verified = true
  first_name     = "App"
  last_name      = "Developer"

  required_actions = ["UPDATE_PASSWORD", "CONFIGURE_TOTP"]
}

resource "keycloak_user_groups" "developer_groups" {
  realm_id = keycloak_realm.lab.id
  user_id  = keycloak_user.developer.id
  group_ids = [
    keycloak_group.developers.id,
  ]
}

# --- Permanent automation identity: Terraform admin service-account client ---
#
# The bootstrap admin is temporary (removed after this apply — see the hardening
# step in the article). This client is the durable, least-privilege identity for
# managing the realm going forward: it uses the OIDC client-credentials grant
# (a service account), not a human password. Its secret is generated ephemerally
# and stored in OpenBao — never in state.

ephemeral "random_password" "tf_admin_secret" {
  length  = 32
  special = false
}

locals {
  tf_admin_secret_revision = 1
}

# Service-account client in the master realm so it can administer realms via the
# admin API. access_type CONFIDENTIAL + service_accounts_enabled = client
# credentials grant; standard (browser) flow disabled.
resource "keycloak_openid_client" "terraform_admin" {
  realm_id  = "master"
  client_id = var.tf_admin_client_id
  name      = "Terraform Admin (automation)"
  enabled   = true

  access_type              = "CONFIDENTIAL"
  service_accounts_enabled = true
  standard_flow_enabled    = false
  direct_access_grants_enabled = false

  client_secret_wo         = ephemeral.random_password.tf_admin_secret.result
  client_secret_wo_version = local.tf_admin_secret_revision
}

# Grant the service account the master realm's "admin" REALM role. In the master
# realm this composite role confers full administrative access across all realms
# — the same power the bootstrap admin has — so the SA can manage the
# credentials-lab realm after the bootstrap admin is removed.
#
# NOTE: "admin" here is a *realm* role of the master realm, NOT a client role on
# the master-realm client (whose roles are realm-admin/manage-users/etc.). So we
# use keycloak_role WITHOUT client_id, and the *_service_account_realm_role
# resource to assign it.
data "keycloak_role" "master_admin" {
  realm_id = "master"
  name     = "admin"
}

resource "keycloak_openid_client_service_account_realm_role" "tf_admin" {
  realm_id                = "master"
  service_account_user_id = keycloak_openid_client.terraform_admin.service_account_user_id
  role                    = data.keycloak_role.master_admin.name
}

# Store the automation client's credentials in OpenBao (write-only, not in
# state). Future runs read these back ephemerally to configure the provider —
# so no standing human admin password exists anywhere.
resource "vault_kv_secret_v2" "tf_admin" {
  mount = var.openbao_kv_mount
  name  = var.openbao_kv_tf_admin_path

  data_json_wo = jsonencode({
    client_id     = var.tf_admin_client_id
    client_secret = ephemeral.random_password.tf_admin_secret.result
  })
  data_json_wo_version = local.tf_admin_secret_revision
}
