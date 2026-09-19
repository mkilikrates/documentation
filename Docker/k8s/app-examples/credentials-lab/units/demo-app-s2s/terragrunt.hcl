include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/demo-app-s2s"
}

# Reusable unit — per-deployment config comes from the stack via `values`.
inputs = {
  namespace           = values.namespace
  vault_internal_addr = values.vault_internal_addr
  trust_domain        = values.trust_domain
}
