# OpenTofu State Management Lab

A hands-on lab to learn OpenTofu state management concepts using a local Kind cluster. You'll deploy infrastructure, introduce drift, practice imports/removals, and perform a full migration to Terragrunt.

## Why OpenTofu?

In August 2023, HashiCorp changed Terraform's license from MPL-2.0 to the Business Source License (BSL 1.1), restricting commercial use by competitors. In response, the community forked Terraform 1.5.x into [OpenTofu](https://opentofu.org/) — an open-source alternative governed by the Linux Foundation under MPL-2.0.

For this lab, OpenTofu and Terraform are functionally equivalent. All concepts (state files, import, removed blocks, providers) work the same way. We use OpenTofu because:

- It's fully open-source with community governance
- The CLI is a drop-in replacement (`tofu` instead of `terraform`)
- All providers from the Terraform registry work unchanged
- Features like `import` blocks and `removed` blocks are supported

> **Note:** If you're using Terraform, replace `tofu` with `terraform` in all commands. Everything else remains the same.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) — see also [Docker/k8s/kind-cluster](../Docker/k8s/kind-cluster/) for detailed setup
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [OpenTofu](https://opentofu.org/docs/intro/install/) (v1.6+)
- [Helm](https://helm.sh/docs/intro/install/) (for manual upgrade in drift exercise)
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) (v1.0+ for Phase 5)

## Learning Path

| Phase | Topic | What You'll Learn |
|-------|-------|-------------------|
| [01-cluster](./01-cluster/) | Bootstrap | Create a Kind cluster with port mappings |
| [02-deploy](./02-deploy/) | Deploy with OpenTofu | Use Helm and Kubernetes providers to deploy apps |
| [03-drift-and-refresh](./03-drift-and-refresh/) | Drift Detection | Detect and handle configuration drift |
| [04-import-and-remove](./04-import-and-remove/) | Import & Remove | Bring external resources under management, remove orphans |
| [05-terragrunt-migration](./05-terragrunt-migration/) | Migration | Migrate from monolithic state to Terragrunt with DRY modules |
| [06-cleanup](./06-cleanup/) | Cleanup | Tear everything down |

## Quick Reference

| Command | Description |
|---------|-------------|
| `tofu init` | Initialize providers and modules |
| `tofu plan` | Preview changes (detect drift) |
| `tofu apply` | Apply changes |
| `tofu apply -refresh-only` | Update state without changing infrastructure |
| `tofu state list` | List all resources in state |
| `tofu state show <resource>` | Show details of a specific resource |
| `tofu state rm <resource>` | Remove a resource from state (doesn't delete it) |
| `tofu import <resource> <id>` | Import existing infrastructure into state |

## Further Reading

- [OpenTofu Documentation](https://opentofu.org/docs/)
- [OpenTofu State Documentation](https://opentofu.org/docs/language/state/)
- [OpenTofu Import Blocks](https://opentofu.org/docs/language/import/)
- [OpenTofu Removed Blocks](https://opentofu.org/docs/language/resources/syntax/#removing-resources)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [NGINX Gateway Fabric](https://github.com/nginx/nginx-gateway-fabric) — see also [Docker/k8s/nginx-fabric](../Docker/k8s/nginx-fabric/)
- [Kind Cluster Setup](../Docker/k8s/kind-cluster/)
