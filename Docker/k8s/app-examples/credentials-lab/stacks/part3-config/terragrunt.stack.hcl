locals {
  name   = "credentials-lab"
  domain = "${get_env("MY_PRIVATE_IP", "127.0.0.1")}.nip.io"
}

# Part 3 (config): Database secrets engine + api-server demo app
#
# Configures OpenBao's database secrets engine (needs a token AND a running
# PostgreSQL for verify_connection), then deploys the demo app that fetches
# Just-In-Time DB credentials. Split from part3-infra because these units use
# the vault provider — same pattern as part1-config.
#
# Prerequisites:
#   - stacks/part3-infra applied and PostgreSQL Running
#   - OpenBao initialized and unsealed
#   - VAULT_ADDR and VAULT_TOKEN env vars set
#
# Usage:
#   export MY_PRIVATE_IP="$(ip addr show $(route | grep '^default' | grep -o '[^ ]*$') | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
#   export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
#   export VAULT_TOKEN="<token>"
#   cd stacks/part3-config
#   terragrunt stack run apply

unit "openbao-database" {
  source                  = "../../units/openbao-database"
  path                    = "openbao-database"
  no_dot_terragrunt_stack = false
  values = {
    kubernetes_auth_path = "kubernetes"
    namespace            = "database-demo"
    postgres_host        = "postgres.database-demo.svc.cluster.local"
    postgres_port        = 5432
    postgres_db          = "app"
    postgres_admin_user  = "postgres"
    openbao_kv_mount     = "secret"
    openbao_kv_path      = "postgres/admin"
    default_ttl          = 1800
    max_ttl              = 3600
  }
}

unit "demo-app-db" {
  source                  = "../../units/demo-app-db"
  path                    = "demo-app-db"
  no_dot_terragrunt_stack = false
  values = {
    namespace           = "database-demo"
    vault_internal_addr = "http://openbao-active.openbao-system.svc.cluster.local:8200"
    db_host             = "postgres.database-demo.svc.cluster.local"
    db_name             = "app"
    replicas            = 3
    expose_gateway      = true
    gateway_domain      = local.domain
  }
}
