#!/bin/bash
# -------------------------------------------------------------------
# Cleanup Script
# Destroys all lab resources and removes the Kind cluster
# -------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== OpenTofu State Lab — Full Cleanup ==="
echo ""

# Try Terragrunt destroy first (Phase 5 structure)
if [ -d "$LAB_DIR/05-terragrunt-migration/local/kind-cluster/nginx-fabric/.terragrunt-cache" ]; then
  echo "Destroying Terragrunt-managed resources..."
  cd "$LAB_DIR/05-terragrunt-migration/local/kind-cluster"
  terragrunt run --all destroy --terragrunt-non-interactive || true
  echo ""
fi

# Try OpenTofu destroy - apps first, then infra
if [ -f "$LAB_DIR/02-deploy/apps/terraform.tfstate" ]; then
  echo "Destroying apps..."
  cd "$LAB_DIR/02-deploy/apps"
  tofu destroy -auto-approve || true
  echo ""
fi

if [ -f "$LAB_DIR/02-deploy/infra/terraform.tfstate" ]; then
  echo "Destroying infra..."
  cd "$LAB_DIR/02-deploy/infra"
  tofu destroy -auto-approve || true
  echo ""
fi

# Delete Kind cluster
echo "Deleting Kind cluster..."
kind delete cluster 2>/dev/null || true

# Clean up state files and directories
echo "Removing state files and .terraform directories..."
rm -f "$LAB_DIR"/02-deploy/infra/terraform.tfstate*
rm -rf "$LAB_DIR"/02-deploy/infra/.terraform
rm -f "$LAB_DIR"/02-deploy/apps/terraform.tfstate*
rm -rf "$LAB_DIR"/02-deploy/apps/.terraform
rm -f "$LAB_DIR"/05-terragrunt-migration/.tfstate/local/kind-cluster/nginx-fabric/terraform.tfstate*
rm -f "$LAB_DIR"/05-terragrunt-migration/.tfstate/local/kind-cluster/app_red/terraform.tfstate*
rm -f "$LAB_DIR"/05-terragrunt-migration/.tfstate/local/kind-cluster/app_blue/terraform.tfstate*
rm -f "$LAB_DIR"/05-terragrunt-migration/.tfstate/local/kind-cluster/app_green/terraform.tfstate*
rm -rf "$LAB_DIR"/05-terragrunt-migration/local/kind-cluster/nginx-fabric/.terragrunt-cache
rm -rf "$LAB_DIR"/05-terragrunt-migration/local/kind-cluster/app_red/.terragrunt-cache
rm -rf "$LAB_DIR"/05-terragrunt-migration/local/kind-cluster/app_blue/.terragrunt-cache
rm -rf "$LAB_DIR"/05-terragrunt-migration/local/kind-cluster/app_green/.terragrunt-cache

# Clean up Terragrunt generated files
rm -f "$LAB_DIR"/05-terragrunt-migration/local/kind-cluster/*/provider.tf
rm -f "$LAB_DIR"/05-terragrunt-migration/local/kind-cluster/*/versions.tf
rm -f "$LAB_DIR"/05-terragrunt-migration/local/kind-cluster/*/backend.tf

# Clean up lock files
rm -f "$LAB_DIR"/02-deploy/infra/.terraform.lock.hcl
rm -f "$LAB_DIR"/02-deploy/apps/.terraform.lock.hcl

echo ""
echo "=== Cleanup complete ==="
echo "Run the lab again starting from: cd $LAB_DIR/01-cluster"
