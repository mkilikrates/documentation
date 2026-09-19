#!/usr/bin/env bash
#
# Part 4: enable "Log in with Keycloak" (OIDC SSO) in Gitea.
#
# Gitea has no Terraform provider for OAuth2 login sources, so we register the
# source at runtime with Gitea's own CLI (via kubectl exec). The Keycloak client
# was created by the keycloak-config module; its secret lives in OpenBao at
# secret/keycloak/gitea-oidc-client — we read it back here (no static secret in
# git or state).
#
# The login source NAME is "keycloak" — it MUST match the path segment in the
# Keycloak client's redirect URI (…/user/oauth2/keycloak/callback), which the
# keycloak-config module set to gitea_external_url/user/oauth2/keycloak/callback.
#
# Idempotent: if a "keycloak" source already exists it is updated, else added.
#
# Prerequisites:
#   - Part 2 applied (Gitea Running)
#   - Part 4 (keycloak-config) applied — the gitea OIDC client + secret exist
#   - Keycloak realm reachable at http://keycloak.${MY_PRIVATE_IP}.nip.io
#   - VAULT_ADDR / VAULT_TOKEN set; MY_PRIVATE_IP set; jq, curl, kubectl available
#
# Usage:
#   export MY_PRIVATE_IP="<your ip>"
#   export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
#   export VAULT_TOKEN="<token>"
#   ./configure-gitea-oidc.sh

set -euo pipefail

: "${MY_PRIVATE_IP:?set MY_PRIVATE_IP}"
: "${VAULT_ADDR:?set VAULT_ADDR}"
: "${VAULT_TOKEN:?set VAULT_TOKEN}"

NAMESPACE="gitea"
KV_MOUNT="secret"
CLIENT_KV_PATH="keycloak/gitea-oidc-client"
SOURCE_NAME="keycloak"
REALM="credentials-lab"
KC_ISSUER="http://keycloak.${MY_PRIVATE_IP}.nip.io/realms/${REALM}"
DISCOVERY_URL="${KC_ISSUER}/.well-known/openid-configuration"

echo "==> Reading the Gitea OIDC client credentials from OpenBao (${CLIENT_KV_PATH})"
CLIENT=$(curl -sf -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/${KV_MOUNT}/data/${CLIENT_KV_PATH}")
CLIENT_ID=$(echo "$CLIENT" | jq -r '.data.data.client_id')
CLIENT_SECRET=$(echo "$CLIENT" | jq -r '.data.data.client_secret')

if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "null" ]; then
  echo "ERROR: could not read the Gitea OIDC client from OpenBao (${CLIENT_KV_PATH})." >&2
  echo "       Apply the part4-config stack (keycloak-config) first." >&2
  exit 1
fi

# Run the Gitea CLI inside the Gitea pod. The chart runs Gitea as the 'git' user;
# `gitea` reads its config from the container automatically.
gitea_cli() {
  kubectl -n "$NAMESPACE" exec deploy/gitea -c gitea -- gitea "$@"
}

# Scopes: Gitea's OIDC login source ALWAYS requests "openid" itself, so we do NOT
# include it here (adding it sends "openid ... openid", which Keycloak rejects as
# "Invalid scopes"). `--scopes` is a REPEATABLE flag (one scope per occurrence),
# NOT a single space-separated string — a single "profile email" would be treated
# as one scope literally named "profile email". We request only profile + email;
# the Keycloak group claim already rides in the token via the gitea_groups mapper,
# so no "groups" scope is needed for login.
COMMON_ARGS=(
  --name "$SOURCE_NAME"
  --provider openidConnect
  --key "$CLIENT_ID"
  --secret "$CLIENT_SECRET"
  --auto-discover-url "$DISCOVERY_URL"
  --scopes profile
  --scopes email
)

echo "==> Checking for an existing '${SOURCE_NAME}' login source"
# `gitea admin auth list` prints a table: ID  Name  Type  Enabled
EXISTING_ID=$(gitea_cli admin auth list 2>/dev/null \
  | awk -v n="$SOURCE_NAME" '$2==n {print $1}' | head -n1 || true)

# Delete any existing source first, then add fresh. update-oauth doesn't reliably
# CLEAR previously-stored scopes, so a stale "openid/groups" scope set can linger
# and keep failing. Delete + add guarantees the source matches this config exactly.
if [ -n "$EXISTING_ID" ]; then
  echo "==> Removing existing login source (id ${EXISTING_ID}) to reset scopes cleanly"
  gitea_cli admin auth delete --id "$EXISTING_ID"
fi

echo "==> Adding OIDC login source '${SOURCE_NAME}'"
gitea_cli admin auth add-oauth "${COMMON_ARGS[@]}"

echo
echo "==> Done. Gitea now shows a 'Sign in with ${SOURCE_NAME}' button at"
echo "    http://gitea.${MY_PRIVATE_IP}.nip.io/user/login"
echo
echo "    Log in as a Keycloak user (e.g. 'developer'; temp password in OpenBao"
echo "    at secret/keycloak/users/developer). On first SSO login Gitea creates"
echo "    the local account from the OIDC profile."
