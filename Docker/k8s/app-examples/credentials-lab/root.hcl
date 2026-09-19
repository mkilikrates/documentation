locals {
  common_vars = yamldecode(file(find_in_parent_folders("common_vars.yaml")))
  env_vars    = yamldecode(file(find_in_parent_folders("env.yaml")))

  env          = local.env_vars.env
  cluster_name = local.env_vars.cluster_name
  domain       = local.env_vars.domain

  tags = merge(
    local.common_vars.tags,
    {
      environment = local.env
    }
  )
}

# Local backend — no cloud state bucket needed
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "local" {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
}
EOF
}

generate "provider_versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  # 1.11+ required for ephemeral resources / write-only attributes, which we use
  # to keep generated secrets out of state (see Part 4 Keycloak zero-standing-admin).
  required_version = ">= 1.11.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    vault = {
      # v5+ for ephemeral vault_kv_secret_v2 + write-only KV attributes
      # (used to keep secrets out of state — Part 4 zero-standing-admin).
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
EOF
}

generate "provider_k8s" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-${local.cluster_name}"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "kind-${local.cluster_name}"
  }
}
EOF
}
