include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/demo-app-db"
}

# Reusable unit — per-deployment config comes from the stack via `values`.
inputs = {
  namespace           = values.namespace
  vault_internal_addr = values.vault_internal_addr
  db_host             = values.db_host
  db_name             = values.db_name
  replicas            = try(values.replicas, 3)
  expose_gateway      = try(values.expose_gateway, true)
  gateway_domain      = values.gateway_domain
}
