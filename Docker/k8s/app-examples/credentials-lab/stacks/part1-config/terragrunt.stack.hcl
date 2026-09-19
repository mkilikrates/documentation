locals {
  name = "credentials-lab"
}

# Part 1 — Phase 3: OpenBao Configuration
#
# Configures auth methods, policies, and audit backends.
# Requires OpenBao to be initialized and unsealed (Phase 2).
#
# Prerequisites:
#   - stacks/part1-infra applied successfully
#   - OpenBao initialized and unsealed
#   - Port-forward running: kubectl -n openbao-system port-forward svc/openbao 8200:8200 &
#   - Environment variables set:
#       export VAULT_ADDR="http://127.0.0.1:8200"
#       export VAULT_TOKEN="<root-token-from-init>"

unit "openbao-config" {
  source                  = "../../units/openbao-config"
  path                    = "openbao-config"
  no_dot_terragrunt_stack = false
  values = {
    kubernetes_host  = "https://kubernetes.default.svc.cluster.local:443"
    enable_kv_engine = true
  }
}
