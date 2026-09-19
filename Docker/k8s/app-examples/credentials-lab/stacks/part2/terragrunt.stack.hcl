locals {
  name   = "credentials-lab"
  domain = "${get_env("MY_PRIVATE_IP", "127.0.0.1")}.nip.io"
}

# Part 2: Service-to-Service & CI/CD Pipeline Credentials
#
# Adds: Gitea (git hosting + CI/CD) + OpenBao JWT/identity token configuration
#
# Prerequisites:
#   - stacks/part1-infra applied (cluster + nginx-gateway + spire + openbao)
#   - OpenBao initialized and unsealed
#   - stacks/part1-config applied (kubernetes auth + base policies)
#   - VAULT_ADDR and VAULT_TOKEN env vars set
#
# Usage:
#   export MY_PRIVATE_IP="$(ip addr show $(route | grep '^default' | grep -o '[^ ]*$') | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
#   export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
#   export VAULT_TOKEN="<token>"
#   terragrunt stack run apply

unit "gitea" {
  source                  = "../../units/gitea"
  path                    = "gitea"
  no_dot_terragrunt_stack = false
  values = {
    namespace        = "gitea"
    admin_username   = "gitea_admin"
    admin_email      = "admin@credentials-lab.local"
    domain           = local.domain
    openbao_kv_mount = "secret"
    openbao_kv_path  = "gitea/admin"
  }
}

unit "openbao-jwt-config" {
  source                  = "../../units/openbao-jwt-config"
  path                    = "openbao-jwt-config"
  no_dot_terragrunt_stack = false
  values = {
    kubernetes_auth_path = "kubernetes"
    enable_gitea_jwt     = true
  }
}

# Service-to-service demo app (frontend + backend + attacker).
# Depends on openbao-jwt-config: the frontend/backend k8s auth roles and the
# service-token OIDC role must exist before the pods can authenticate.
unit "demo-app-s2s" {
  source                  = "../../units/demo-app-s2s"
  path                    = "demo-app-s2s"
  no_dot_terragrunt_stack = false
  values = {
    namespace           = "credentials-demo"
    vault_internal_addr = "http://openbao-active.openbao-system.svc.cluster.local:8200"
    trust_domain        = "cluster.local"
  }
}
