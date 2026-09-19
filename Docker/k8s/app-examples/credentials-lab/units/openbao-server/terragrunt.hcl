include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "spire" {
  config_path = "../spire"

  mock_outputs = {
    namespace    = "spire-system"
    trust_domain = "cluster.local"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "nginx_gateway" {
  config_path = "../nginx-gateway"

  mock_outputs = {
    gateway_name      = "shared-gateway"
    gateway_namespace = "nginx-gateway"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

terraform {
  source = "../../../../modules/openbao-server"
}

# Reusable unit — per-deployment config comes from the stack via `values`.
#
# `replicas` defaults to 1 when the stack doesn't set it: on a fresh cluster we
# bootstrap openbao-0 alone (no Raft join race — see openbao/openbao#2274), then
# the stack raises replicas to 3 after openbao-0 is initialised + unsealed.
inputs = {
  namespace           = values.namespace
  replicas            = try(values.replicas, 1)
  openbao_version     = values.openbao_version
  storage_size        = values.storage_size
  enable_csi_provider = try(values.enable_csi_provider, true)
  enable_injector     = try(values.enable_injector, true)
  expose_nodeport     = try(values.expose_nodeport, false)
  expose_gateway      = try(values.expose_gateway, true)
  gateway_domain      = values.gateway_domain
}
