# Part 1 — Phase 1: Infrastructure
#
# Deploys: NGINX Gateway Fabric → SPIRE → OpenBao server (exposed via Gateway API)
# No OpenBao token required — the server is deployed but uninitialized.
#
# OpenBao starts with replicas = 1 on purpose: openbao-0 bootstraps as the Raft
# leader without a join race (openbao/openbao#2274). After you initialise +
# unseal openbao-0 (see the article), set openbao_replicas = 3 below and
# re-apply, then unseal openbao-1 / openbao-2.
#
# After this stack completes:
#   1. Initialize and unseal OpenBao (see article)
#   2. Scale to HA (openbao_replicas = 3, re-apply, unseal joiners)
#   3. Run stacks/part1-config with VAULT_ADDR pointing to the gateway URL

locals {
  name         = "credentials-lab"
  cluster_name = "credentials-lab"
  domain       = "${get_env("MY_PRIVATE_IP", "127.0.0.1")}.nip.io"

  # Bump to 3 after openbao-0 is initialised + unsealed, then re-apply.
  openbao_replicas = 1
}

unit "nginx-gateway" {
  source                  = "../../units/nginx-gateway"
  path                    = "nginx-gateway"
  no_dot_terragrunt_stack = false
  values = {
    control_plane_node = "${local.cluster_name}-control-plane"
    domain             = local.domain
  }
}

unit "spire" {
  source                  = "../../units/spire"
  path                    = "spire"
  no_dot_terragrunt_stack = false
  values = {
    namespace    = "spire-system"
    trust_domain = "cluster.local"
    cluster_name = "kind-${local.cluster_name}"
  }
}

unit "openbao-server" {
  source                  = "../../units/openbao-server"
  path                    = "openbao-server"
  no_dot_terragrunt_stack = false
  values = {
    namespace           = "openbao-system"
    replicas            = local.openbao_replicas
    openbao_version     = "2.6.2"
    storage_size        = "1Gi"
    enable_csi_provider = true
    enable_injector     = true
    expose_nodeport     = false
    expose_gateway      = true
    gateway_domain      = local.domain
  }
}
