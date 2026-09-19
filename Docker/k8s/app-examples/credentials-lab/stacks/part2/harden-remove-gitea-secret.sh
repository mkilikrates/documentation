#!/usr/bin/env bash
#
# Part 2 hardening: remove the Gitea admin Kubernetes Secret after bootstrap.
#
# Gitea is deployed with admin.passwordMode = initialOnlyNoReset, so the chart
# reads the admin credential from the K8s Secret ONLY at initial creation.
# After Gitea exists, it keeps its own hashed credential internally and no
# longer needs the Secret — so we can delete it, leaving the durable copy only
# in OpenBao (secret/gitea/admin). This removes the standing base64 credential
# from etcd.
#
# Why a manual step (not part of `terragrunt apply`): Terraform manages the
# Secret resource, so an apply would recreate it. This script deletes it
# out-of-band after you've confirmed Gitea is up. NOTE: a later `terragrunt
# apply` of the part2 stack will recreate the Secret (Tofu sees it missing) —
# just re-run this script afterward, or remove the gitea_admin secret resource
# from the module once you no longer need to re-bootstrap.
#
# Prerequisites:
#   - part2 applied and Gitea Running
#   - VAULT_ADDR / VAULT_TOKEN set (to read the admin creds from OpenBao)
#   - jq, curl available; kubectl context on the lab cluster
#
# Usage:
#   export MY_PRIVATE_IP="<your ip>"
#   export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
#   export VAULT_TOKEN="<token>"
#   ./harden-remove-gitea-secret.sh

set -euo pipefail

: "${MY_PRIVATE_IP:?set MY_PRIVATE_IP}"
: "${VAULT_ADDR:?set VAULT_ADDR}"
: "${VAULT_TOKEN:?set VAULT_TOKEN}"

NAMESPACE="gitea"
SECRET_NAME="gitea-admin"
GITEA_URL="http://gitea.${MY_PRIVATE_IP}.nip.io"
KV_PATH="gitea/admin"

echo "==> Reading Gitea admin credentials from OpenBao"
CREDS=$(curl -sf -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/secret/data/${KV_PATH}")
USERNAME=$(echo "$CREDS" | jq -r '.data.data.username')
PASSWORD=$(echo "$CREDS" | jq -r '.data.data.password')

if [ -z "$USERNAME" ] || [ "$USERNAME" = "null" ]; then
  echo "ERROR: could not read Gitea admin credentials from OpenBao ($KV_PATH)." >&2
  exit 1
fi

echo "==> Verifying the admin account works via the Gitea API (before removing the Secret)"
CODE=$(curl -s -o /dev/null -w '%{http_code}' \
  -u "${USERNAME}:${PASSWORD}" \
  "${GITEA_URL}/api/v1/user")

if [ "$CODE" != "200" ]; then
  echo "ERROR: Gitea admin login check returned HTTP $CODE (expected 200)." >&2
  echo "       Aborting — NOT removing the Secret. Confirm Gitea is up and the" >&2
  echo "       credential in OpenBao is correct before retrying." >&2
  exit 1
fi
echo "    admin login OK (HTTP 200)."

if ! kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" >/dev/null 2>&1; then
  echo "==> Secret ${NAMESPACE}/${SECRET_NAME} not present (already removed?). Nothing to do."
  exit 0
fi

echo "==> Deleting Kubernetes Secret ${NAMESPACE}/${SECRET_NAME}"
kubectl -n "$NAMESPACE" delete secret "$SECRET_NAME"

echo "==> Done. The Gitea admin credential now lives only in OpenBao ($KV_PATH)."
echo "    Gitea keeps its own hashed copy and does not need the Secret again"
echo "    (passwordMode = initialOnlyNoReset)."
echo
echo "    Reminder: re-applying the part2 stack recreates the Secret. Re-run this"
echo "    script if that happens."
