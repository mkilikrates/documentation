# -------------------------------------------------------------------
# Root Terragrunt configuration
# Shared settings inherited by all child modules across all environments.
# Following the Gruntwork recommended structure:
#   root.hcl          → global config (backend, providers, versions)
#   modules/          → reusable modules (infrastructure-modules)
#   local/            → environment (infrastructure-live)
#     kind-cluster/   → cluster-specific components
# -------------------------------------------------------------------

locals {
  # Load environment config from the nearest env.hcl
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

# Use OpenTofu instead of Terraform
terraform {
  extra_arguments "common" {
    commands = get_terraform_commands_that_need_vars()
  }
}

# Store state files in a predictable location for visibility
# Each component gets: .tfstate/<environment>/<cluster>/<component>/terraform.tfstate
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "local" {
    path = "${get_parent_terragrunt_dir()}/.tfstate/${path_relative_to_include()}/terraform.tfstate"
  }
}
EOF
}

# Generate provider configuration using environment variables
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "kubernetes" {
  config_path    = "${local.env.config_path}"
  config_context = "${local.env.config_context}"
}

provider "helm" {
  kubernetes = {
    config_path    = "${local.env.config_path}"
    config_context = "${local.env.config_context}"
  }
}

provider "kubectl" {
  config_path    = "${local.env.config_path}"
  config_context = "${local.env.config_context}"
}
EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
  }
}
EOF
}
