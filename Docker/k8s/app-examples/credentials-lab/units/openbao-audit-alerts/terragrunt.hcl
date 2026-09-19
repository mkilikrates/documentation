include "root" {
  path = find_in_parent_folders("root.hcl")
  # Deep merge so this unit's generate "provider_versions" block OVERRIDES the
  # one inherited from root (to add the grafana provider) instead of colliding.
  merge_strategy = "deep"
  expose         = true
}

terraform {
  source = "../../../../modules/openbao-audit-alerts"
}

# Override root.hcl's generated versions.tf to ADD the grafana provider.
# Same block name as the parent ("provider_versions") so this child overrides it.
# The module must not declare its own required_providers (one per module).
generate "provider_versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.11.0"
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.18"
    }
  }
}
EOF
}

# This unit talks only to Grafana — no Kubernetes/Helm. Override root.hcl's
# generated providers.tf (k8s + helm provider blocks) with an empty file so we
# don't declare unused providers that would need cluster access.
generate "provider_k8s" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = "# intentionally empty — this unit uses only the grafana provider\n"
}

# Grafana provider — points at the Grafana installed by part5-infra. Auth via
# GRAFANA_AUTH (either "user:password" basic auth using the generated admin
# credential from OpenBao secret/grafana/admin, or a Grafana service-account
# token). URL via GRAFANA_URL (e.g. http://grafana.<MY_PRIVATE_IP>.nip.io).
generate "provider_grafana" {
  path      = "provider_grafana.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "grafana" {
  url  = "${get_env("GRAFANA_URL", "http://grafana.127.0.0.1.nip.io")}"
  auth = "${get_env("GRAFANA_AUTH", "admin:admin")}"
}
EOF
}

# Reusable unit — per-deployment config comes from the stack via `values`.
inputs = {
  folder_title        = try(values.folder_title, "Security - Credentials")
  loki_datasource_uid = try(values.loki_datasource_uid, "loki")
  openbao_namespace   = try(values.openbao_namespace, "openbao-system")

  # Must match the openbao-canary module's read path: <mount>/data/<canary_path>
  canary_path = values.canary_path

  burst_threshold       = try(values.burst_threshold, 10)
  eval_interval_seconds = try(values.eval_interval_seconds, 60)
  runbook_url           = try(values.runbook_url, "https://example.internal/runbooks/credential-leak")
}
