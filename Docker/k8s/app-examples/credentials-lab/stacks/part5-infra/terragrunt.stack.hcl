locals {
  name   = "credentials-lab"
  domain = "${get_env("MY_PRIVATE_IP", "127.0.0.1")}.nip.io"
}

# Part 5 (infra): Observability stack for credential leak detection.
#
# Installs a lean logging pipeline — Loki (single-binary, filesystem), Alloy
# (pod-log collector), and Grafana (Loki datasource pre-provisioned). OpenBao's
# audit device already writes JSON to stdout (see modules/openbao-server), so
# Alloy ships audit records to Loki as normal pod logs — no extra wiring.
#
# This is a SUBSET of the "Kubernetes Observability with Grafana Stack" series.
# If you already ran that stack in this cluster, set install_loki/install_alloy/
# install_grafana = false in units/observability and reuse it instead.
#
# The Grafana admin password is generated (ephemeral), stored write-only in a
# K8s Secret AND in OpenBao at secret/grafana/admin — never in Terraform state.
#
# Prerequisites:
#   - stacks/part1-infra applied (cluster + nginx-gateway + openbao)
#   - stacks/part1-config applied (OpenBao initialized/unsealed, KV enabled)
#   - VAULT_ADDR and VAULT_TOKEN set (to store the Grafana admin credential)
#
# Usage:
#   export MY_PRIVATE_IP="$(ip addr show $(route | grep '^default' | grep -o '[^ ]*$') | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
#   export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
#   export VAULT_TOKEN="<token>"
#   cd stacks/part5-infra
#   terragrunt stack run apply
#   kubectl -n monitoring rollout status deploy/grafana

unit "observability" {
  source                  = "../../units/observability"
  path                    = "observability"
  no_dot_terragrunt_stack = false
  values = {
    namespace        = "monitoring"
    create_namespace = true

    # Set these to false to reuse an existing Observability-series stack.
    install_loki    = true
    install_alloy   = true
    install_grafana = true

    grafana_admin_secret_name = "grafana-admin"
    store_admin_in_openbao    = true
    openbao_kv_mount          = "secret"
    openbao_kv_path           = "grafana/admin"

    expose_gateway = true
    gateway_domain = local.domain
  }
}
