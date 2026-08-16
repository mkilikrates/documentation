# -------------------------------------------------------------------
# NGINX Gateway Fabric component
# Uses the shared nginx-fabric module — same module could be reused
# for another cluster/environment with different inputs.
# -------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/nginx-fabric"
}

inputs = {
  private_ip           = "" # Auto-detected; override with TF_VAR_private_ip
  nginx_fabric_version = "2.6.7"
  gateway_api_version  = "1.5.0"
}
