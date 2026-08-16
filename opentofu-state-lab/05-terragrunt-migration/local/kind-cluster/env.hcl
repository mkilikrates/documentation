# -------------------------------------------------------------------
# Environment configuration for the local Kind cluster
# Shared inputs inherited by all components in this environment.
# To add another cluster, create a sibling folder (e.g., kind-cluster-2/)
# with its own env.hcl and different values.
# -------------------------------------------------------------------

locals {
  environment     = "local"
  cluster_name    = "kind-kind"
  config_context  = "kind-kind"
  config_path     = "~/.kube/config"
}
