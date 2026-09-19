include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/spire"
}

# Reusable unit — per-deployment config comes from the stack via `values`.
inputs = {
  namespace    = values.namespace
  trust_domain = values.trust_domain
  cluster_name = values.cluster_name
}
