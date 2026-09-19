#!/usr/bin/env bash
#
# Part 4 hardening: remove Keycloak's temporary bootstrap admin.
#
# Why this is a separate step (not part of `terragrunt apply`):
#   The keycloak provider authenticates AS the bootstrap admin to create the
#   realm and the permanent `terraform-admin` service-account client. Deleting
#   the bootstrap admin in the same apply that authenticates as it is a
#   chicken-and-egg that Terraform can't order safely. So we create the durable
#   service account during apply, then run this once to (1) confirm the service
#   account works and (2) delete the bootstrap admin. After this, NO standing
#   human admin password exists — only the service-account credential, which
#   lives in OpenBao.
#
# Prerequisites:
#   - part4-infra + part4-config applied
#   - VAULT_ADDR and VAULT_TOKEN set (to read the SA creds from OpenBao)
#   - jq and curl available
#
# Usage:
#   export MY_PRIVATE_IP="<your ip>"
#   export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
#   export VAULT_TOKEN="<token>"
#   ./harden-remove-bootstrap-admin.sh

set -euo pipefail

: "${MY_PRIVATE_IP:?set MY_PRIVATE_IP}"
: "${VAULT_ADDR:?set VAULT_ADDR}"
: "${VAULT_TOKEN:?set VAULT_TOKEN}"

KC_URL="http://keycloak.${MY_PRIVATE_IP}.nip.io"
KV_MOUNT="secret"
SA_PATH="keycloak/terraform-admin"
BOOTSTRAP_PATH="keycloak/bootstrap-admin"

echo "==> Reading terraform-admin service-account credentials from OpenBao"
SA_JSON=$(curl -sf -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/$KV_MOUNT/data/$SA_PATH")
SA_CLIENT_ID=$(echo "$SA_JSON" | jq -r '.data.data.client_id')
SA_CLIENT_SECRET=$(echo "$SA_JSON" | jq -r '.data.data.client_secret')

echo "==> Verifying the service account can obtain an admin token (client credentials grant)"
SA_TOKEN=$(curl -sf --request POST \
  "$KC_URL/realms/master/protocol/openid-connect/token" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=${SA_CLIENT_ID}" \
  --data-urlencode "client_secret=${SA_CLIENT_SECRET}" | jq -r '.access_token')

if [ -z "$SA_TOKEN" ] || [ "$SA_TOKEN" = "null" ]; then
  echo "ERROR: service account could not authenticate. Aborting — NOT removing bootstrap admin." >&2
  exit 1
fi
echo "    service account authenticates OK."

echo "==> Locating the bootstrap admin user in the master realm"
BOOTSTRAP_USER=$(curl -sf -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/$KV_MOUNT/data/$BOOTSTRAP_PATH" | jq -r '.data.data.username')

USER_ID=$(curl -sf -H "Authorization: Bearer $SA_TOKEN" \
  "$KC_URL/admin/realms/master/users?username=${BOOTSTRAP_USER}&exact=true" \
  | jq -r '.[0].id // empty')

if [ -z "$USER_ID" ]; then
  echo "    bootstrap admin '${BOOTSTRAP_USER}' not found (already removed?). Nothing to do."
  exit 0
fi

echo "==> Deleting bootstrap admin '${BOOTSTRAP_USER}' (id=${USER_ID}) using the service account"
curl -sf -X DELETE -H "Authorization: Bearer $SA_TOKEN" \
  "$KC_URL/admin/realms/master/users/${USER_ID}"

echo "==> Done. Bootstrap admin removed."
echo "    From here on, realm administration uses the 'terraform-admin' service"
echo "    account (credentials in OpenBao at $KV_MOUNT/$SA_PATH). No standing"
echo "    human admin password remains."
echo
echo "    NOTE: to let future 'terragrunt apply' runs use the service account"
echo "    instead of the (now-deleted) bootstrap admin, switch the keycloak"
echo "    provider to client-credentials auth — see the article's hardening note."
