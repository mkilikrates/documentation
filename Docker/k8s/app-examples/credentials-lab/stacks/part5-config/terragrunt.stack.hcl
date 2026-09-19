locals {
  name = "credentials-lab"
}

# Part 5 (config): Leak-detection configuration — canary + Grafana alert rules.
#
#   openbao-canary      — plants a honey-token (deliberately fake) plus a trap
#                         policy attached to no role. Any read of it is a probe.
#   openbao-audit-alerts — Grafana alert rules over the OpenBao audit log in Loki
#                         (canary read, break-glass usage, credential burst).
#
# Split from part5-infra because these units use the vault and grafana providers
# (same split rationale as part1/part3/part4 config vs infra).
#
# Prerequisites:
#   - stacks/part1-config applied (OpenBao KV engine enabled)
#   - stacks/part3-config applied (database secrets engine — so break-glass /
#     burst alerts have real credential-issuance events to match)
#   - stacks/part5-infra applied (Grafana + Loki up, Loki datasource uid "loki")
#   - VAULT_ADDR / VAULT_TOKEN set (for the canary)
#   - GRAFANA_URL / GRAFANA_AUTH set (for the alert rules)
#
# Getting GRAFANA_AUTH from the generated admin credential in OpenBao:
#   export MY_PRIVATE_IP="$(ip addr show $(route | grep '^default' | grep -o '[^ ]*$') | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
#   export GRAFANA_URL="http://grafana.${MY_PRIVATE_IP}.nip.io"
#   GRAFANA_PW=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
#     "$VAULT_ADDR/v1/secret/data/grafana/admin" | jq -r .data.data.password)
#   export GRAFANA_AUTH="admin:${GRAFANA_PW}"
#
# GRAFANA_URL MUST use $MY_PRIVATE_IP — the host the part5-infra stack created the
# Grafana HTTPRoute for. If MY_PRIVATE_IP is empty, GRAFANA_URL falls back to
# grafana.127.0.0.1.nip.io, which the gateway can't route, and the apply fails
# with a 404 on "POST /folders". Verify before applying (expect 200):
#   curl -s -o /dev/null -w '%{http_code}\n' -u "$GRAFANA_AUTH" "$GRAFANA_URL/api/folders"
#
# Usage:
#   cd stacks/part5-config
#   terragrunt stack run apply

unit "openbao-canary" {
  source                  = "../../units/openbao-canary"
  path                    = "openbao-canary"
  no_dot_terragrunt_stack = false
  values = {
    kv_mount           = "secret"
    canary_path        = "database/production-admin"
    canary_policy_name = "canary-trap"
  }
}

unit "openbao-audit-alerts" {
  source                  = "../../units/openbao-audit-alerts"
  path                    = "openbao-audit-alerts"
  no_dot_terragrunt_stack = false
  values = {
    folder_title        = "Security - Credentials"
    loki_datasource_uid = "loki"
    openbao_namespace   = "openbao-system"
    # Must match the canary module's read path: <mount>/data/<canary_path>
    canary_path           = "secret/data/database/production-admin"
    burst_threshold       = 10
    eval_interval_seconds = 60
    runbook_url           = "https://example.internal/runbooks/credential-leak"
  }
}
