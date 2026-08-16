# Phase 6 — Cleanup

Tear down all resources and delete the Kind cluster.

## Option A — Destroy via Terragrunt (if you completed Phase 5)

```bash
cd ../05-terragrunt-migration
terragrunt run-all destroy
```

This destroys all components in reverse dependency order.

## Option B — Destroy via OpenTofu (if you stopped before Phase 5)

```bash
cd ../02-deploy
tofu destroy
```

## Delete the Kind Cluster

Regardless of which option you used above, delete the cluster:

```bash
kind delete cluster
```

This removes all containers, networks, and volumes associated with the Kind cluster.

## Verify Cleanup

```bash
# No Kind clusters should be listed
kind get clusters

# No related Docker containers
docker ps -a | grep kind
```

## Reset for a Fresh Run

If you want to run the lab again from scratch:

```bash
# Remove state files
rm -f 02-deploy/terraform.tfstate*
rm -f 05-terragrunt-migration/nginx-fabric/terraform.tfstate*
rm -f 05-terragrunt-migration/app_red/terraform.tfstate*
rm -f 05-terragrunt-migration/app_blue/terraform.tfstate*
rm -f 05-terragrunt-migration/app_green/terraform.tfstate*

# Remove .terraform directories
rm -rf 02-deploy/.terraform
rm -rf 05-terragrunt-migration/nginx-fabric/.terraform
rm -rf 05-terragrunt-migration/app_red/.terraform
rm -rf 05-terragrunt-migration/app_blue/.terraform
rm -rf 05-terragrunt-migration/app_green/.terraform

# Remove generated files from Terragrunt
rm -f 05-terragrunt-migration/nginx-fabric/provider.tf
rm -f 05-terragrunt-migration/nginx-fabric/versions.tf
rm -f 05-terragrunt-migration/app_*/provider.tf
rm -f 05-terragrunt-migration/app_*/versions.tf
```

Then start again from [Phase 1](../01-cluster/).
