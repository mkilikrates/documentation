include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/nginx-gateway"
}

# Reusable unit — all per-deployment config comes from the stack via `values`.
inputs = {
  control_plane_node = values.control_plane_node
  domain             = values.domain
}
