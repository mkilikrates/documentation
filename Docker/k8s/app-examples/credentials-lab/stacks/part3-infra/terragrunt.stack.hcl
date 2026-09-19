locals {
  name = "credentials-lab"
}

# Part 3 (infra): PostgreSQL
#
# Deploys PostgreSQL into the credentials-demo namespace. Requires NO OpenBao
# token — it's plain Kubernetes/Helm, so it's separated from the config stack
# (which uses the vault provider) exactly like part1-infra / part1-config.
#
# Prerequisites:
#   - stacks/part1-infra applied (cluster)
#   - stacks/part2 applied (creates the credentials-demo namespace)
#
# Usage:
#   cd stacks/part3-infra
#   terragrunt stack run apply
#   kubectl -n credentials-demo rollout status deploy/postgres

unit "postgresql" {
  source                  = "../../units/postgresql"
  path                    = "postgresql"
  no_dot_terragrunt_stack = false
  values = {
    namespace        = "database-demo"
    admin_user       = "postgres"
    database         = "app"
    openbao_kv_mount = "secret"
    openbao_kv_path  = "postgres/admin"
  }
}
