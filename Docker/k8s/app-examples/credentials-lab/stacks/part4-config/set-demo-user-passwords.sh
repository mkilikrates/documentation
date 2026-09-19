#!/usr/bin/env bash
#
# Part 4: set temporary passwords for the demo human users, out-of-band.
#
# The keycloak provider has no write-only password argument, so setting a
# user password in Terraform would persist it to state. Instead the users are
# created WITHOUT a password (with UPDATE_PASSWORD required), and this script
# generates a temporary password for each, stores it in OpenBao, and sets it
# via the Keycloak admin API. Nothing sensitive ever touches Terraform state.
#
# The user must change the password (and enrol TOTP) on first login.
#
# Prerequisites:
#   - part4-infra + part4-config applied
#   - VAULT_ADDR and VAULT_TOKEN set
#   - jq, curl, openssl available
#
# Usage:
#   export MY_PRIVATE_IP="<your ip>"
#   export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
#   export VAULT_TOKEN="<token>"
#   ./set-demo-user-passwords.sh

set -euo pipefail

: "${MY_PRIVATE_IP:?set MY_PRIVATE_IP}"
: "${VAULT_ADDR:?set VAULT_ADDR}"
: "${VAULT_TOKEN:?set VAULT_TOKEN}"

KC_URL="http://keycloak.${MY_PRIVATE_IP}.nip.io"
REALM="credentials-lab"
KV_MOUNT="secret"
SA_PATH="keycloak/terraform-admin"
USERS=("engineer" "developer")

echo "==> Getting an admin token via the terraform-admin service account"
SA_JSON=$(curl -sf -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/$KV_MOUNT/data/$SA_PATH")
SA_CLIENT_ID=$(echo "$SA_JSON" | jq -r '.data.data.client_id')
SA_CLIENT_SECRET=$(echo "$SA_JSON" | jq -r '.data.data.client_secret')

ADMIN_TOKEN=$(curl -sf --request POST \
  "$KC_URL/realms/master/protocol/openid-connect/token" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=${SA_CLIENT_ID}" \
  --data-urlencode "client_secret=${SA_CLIENT_SECRET}" | jq -r '.access_token')

# If the bootstrap admin hasn't been removed yet, you can instead authenticate
# with it (read from OpenBao at secret/keycloak/bootstrap-admin) — but the
# service account is the intended path.

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "ERROR: could not obtain an admin token from the service account." >&2
  exit 1
fi

for USER in "${USERS[@]}"; do
  echo "==> Processing user '${USER}'"

  USER_ID=$(curl -sf -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KC_URL/admin/realms/${REALM}/users?username=${USER}&exact=true" \
    | jq -r '.[0].id // empty')

  if [ -z "$USER_ID" ]; then
    echo "    user '${USER}' not found — skipping." >&2
    continue
  fi

  # Generate a temporary password (not stored in TF state; stored in OpenBao)
  TEMP_PW="$(openssl rand -base64 18)Aa1!"

  echo "    setting temporary password (must change on first login)"
  curl -sf -X PUT -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    "$KC_URL/admin/realms/${REALM}/users/${USER_ID}/reset-password" \
    --data "$(jq -nc --arg p "$TEMP_PW" '{type:"password", value:$p, temporary:true}')"

  echo "    storing the temporary password in OpenBao at ${KV_MOUNT}/keycloak/users/${USER}"
  curl -sf -H "X-Vault-Token: $VAULT_TOKEN" -X POST \
    "$VAULT_ADDR/v1/${KV_MOUNT}/data/keycloak/users/${USER}" \
    --data "$(jq -nc --arg u "$USER" --arg p "$TEMP_PW" '{data:{username:$u, temp_password:$p}}')" >/dev/null

  echo "    done. Retrieve with: curl -s -H \"X-Vault-Token: \$VAULT_TOKEN\" $VAULT_ADDR/v1/${KV_MOUNT}/data/keycloak/users/${USER} | jq -r .data.data.temp_password"
done

echo
echo "==> All demo users have a temporary password stored in OpenBao."
echo "    Log in via the OpenBao UI (OIDC) — first login forces a password"
echo "    change and TOTP enrolment."
