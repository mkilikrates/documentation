# Phase 5 — Terragrunt Migration

Migrate from a monolithic OpenTofu state (all resources in one state file) to a split Terragrunt structure with DRY modules. This is a common real-world scenario when teams outgrow a single state file.

## Why Migrate to Terragrunt?

As infrastructure grows, a single state file creates problems:

| Problem | Impact |
|---------|--------|
| Slow plans | Every `tofu plan` refreshes ALL resources |
| Blast radius | A mistake in one resource can block all changes |
| Team conflicts | Multiple people can't work on different components simultaneously |
| State lock contention | Only one apply at a time for the entire stack |

Terragrunt solves this by splitting state into components and providing DRY configuration through reusable modules.

## What We're Building

Following the [Gruntwork recommended structure](https://docs.gruntwork.io/2.0/docs/overview/concepts/infrastructure-live/):

```
05-terragrunt-migration/
├── root.hcl                              # Root config (backend, providers, versions)
├── modules/                              # Reusable modules (infrastructure-modules)
│   ├── app/                              # Any colored web app
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── nginx-fabric/                     # Gateway API CRDs + NGINX Gateway Fabric
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── local/                                # Environment: "local" (infrastructure-live)
    └── kind-cluster/                     # Cluster level
        ├── env.hcl                       # Shared environment config (IP, kubeconfig)
        ├── nginx-fabric/
        │   └── terragrunt.hcl            # Inputs for this cluster's NGF
        ├── app_red/
        │   └── terragrunt.hcl            # Inputs: name=red, color=#dc3545
        ├── app_blue/
        │   └── terragrunt.hcl            # Inputs: name=blue, color=#0d6efd
        └── app_green/
            └── terragrunt.hcl            # Inputs: name=green, color=#198754
```

**Key concepts:**

- **`modules/`** = reusable code (like a separate `infrastructure-modules` repo). Never changes per environment.
- **`local/kind-cluster/`** = environment-specific config. Only inputs differ.
- **`env.hcl`** = shared variables for all components in this cluster (kubeconfig path, context name).
- **`root.hcl`** = global settings (backend strategy, provider generation, version constraints).

To add a second cluster, you'd just create `local/kind-cluster-2/` with its own `env.hcl` and component folders — same modules, different inputs.

## Prerequisites

- Phases 1–4 completed (cluster running, apps deployed, state in `02-deploy/`)
- [Terragrunt v1.0+](https://terragrunt.gruntwork.io/docs/getting-started/install/) installed

Verify:

```bash
terragrunt --version
```

## Migration Steps

### Step 1 — Initialize Terragrunt

```bash
cd 05-terragrunt-migration/local/kind-cluster
terragrunt run --all init
```

This initializes all components. Each gets its own `.terraform/` directory and state file.

### Step 2 — Import NGINX Gateway Fabric

Import the Gateway API CRDs, Helm release, and related resources into the nginx-fabric component:

```bash
cd nginx-fabric

# Import Gateway API CRDs (cluster-scoped: apiVersion//Kind//name — no namespace)
terragrunt import 'kubectl_manifest.gateway_api_crds["/apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings/safe-upgrades.gateway.networking.k8s.io"]' "admissionregistration.k8s.io/v1//ValidatingAdmissionPolicyBinding//safe-upgrades.gateway.networking.k8s.io"
terragrunt import 'kubectl_manifest.gateway_api_crds["/apis/admissionregistration.k8s.io/v1/validatingadmissionpolicys/safe-upgrades.gateway.networking.k8s.io"]' "admissionregistration.k8s.io/v1//ValidatingAdmissionPolicy//safe-upgrades.gateway.networking.k8s.io"
terragrunt import 'kubectl_manifest.gateway_api_crds["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/backendtlspolicies.gateway.networking.k8s.io"]' "apiextensions.k8s.io/v1//CustomResourceDefinition//backendtlspolicies.gateway.networking.k8s.io"
terragrunt import 'kubectl_manifest.gateway_api_crds["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/gatewayclasses.gateway.networking.k8s.io"]' "apiextensions.k8s.io/v1//CustomResourceDefinition//gatewayclasses.gateway.networking.k8s.io"
terragrunt import 'kubectl_manifest.gateway_api_crds["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/gateways.gateway.networking.k8s.io"]' "apiextensions.k8s.io/v1//CustomResourceDefinition//gateways.gateway.networking.k8s.io"
terragrunt import 'kubectl_manifest.gateway_api_crds["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/grpcroutes.gateway.networking.k8s.io"]' "apiextensions.k8s.io/v1//CustomResourceDefinition//grpcroutes.gateway.networking.k8s.io"
terragrunt import 'kubectl_manifest.gateway_api_crds["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/httproutes.gateway.networking.k8s.io"]' "apiextensions.k8s.io/v1//CustomResourceDefinition//httproutes.gateway.networking.k8s.io"
terragrunt import 'kubectl_manifest.gateway_api_crds["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/listenersets.gateway.networking.k8s.io"]' "apiextensions.k8s.io/v1//CustomResourceDefinition//listenersets.gateway.networking.k8s.io"
terragrunt import 'kubectl_manifest.gateway_api_crds["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/referencegrants.gateway.networking.k8s.io"]' "apiextensions.k8s.io/v1//CustomResourceDefinition//referencegrants.gateway.networking.k8s.io"
terragrunt import 'kubectl_manifest.gateway_api_crds["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/tlsroutes.gateway.networking.k8s.io"]' "apiextensions.k8s.io/v1//CustomResourceDefinition//tlsroutes.gateway.networking.k8s.io"

# Import namespace, helm release, gateway, and proxy config
terragrunt import 'kubernetes_namespace.nginx_gateway' 'nginx-gateway'
terragrunt import 'helm_release.nginx_gateway_fabric' 'nginx-gateway/ngf'
terragrunt import 'kubectl_manifest.shared_gateway' "gateway.networking.k8s.io/v1//Gateway//nginx-shared-gateway//nginx-gateway"
terragrunt import 'kubectl_manifest.nginx_proxy_config' "gateway.nginx.org/v1alpha2//NginxProxy//ngf-proxy-config//nginx-gateway"
```

> **Note:** CRDs are cluster-scoped resources, so their import ID uses format `apiVersion//Kind//name` (3 parts, no namespace). Namespaced resources use `apiVersion//Kind//name//namespace` (4 parts).

Verify:

```bash
terragrunt plan
```

The plan should show no changes (or minimal computed attribute differences).

### Step 3 — Import the Apps

Each app has its own state and namespace now. Before importing, check what's actually running in the cluster:

```bash
kubectl get namespaces | grep -E 'red|blue|green'
```

Import only apps that exist. If you deleted blue in Phase 4 and didn't recreate it, skip the blue import and let Terragrunt create it fresh with `terragrunt apply` later.

```bash
# Red app
cd ../app_red
terragrunt import 'kubernetes_namespace.app' 'red'
terragrunt import 'kubernetes_config_map.html' 'red/red-html'
terragrunt import 'kubernetes_deployment.app' 'red/red-app'
terragrunt import 'kubernetes_service.app' 'red/red-service'
terragrunt import 'kubectl_manifest.httproute' "gateway.networking.k8s.io/v1//HTTPRoute//red-route//red"
terragrunt import 'kubectl_manifest.httproute_path' "gateway.networking.k8s.io/v1//HTTPRoute//red-route-path//red"
```

```bash
# Blue app
cd ../app_blue
terragrunt import 'kubernetes_namespace.app' 'blue'
terragrunt import 'kubernetes_config_map.html' 'blue/blue-html'
terragrunt import 'kubernetes_deployment.app' 'blue/blue-app'
terragrunt import 'kubernetes_service.app' 'blue/blue-service'
terragrunt import 'kubectl_manifest.httproute' "gateway.networking.k8s.io/v1//HTTPRoute//blue-route//blue"
terragrunt import 'kubectl_manifest.httproute_path' "gateway.networking.k8s.io/v1//HTTPRoute//blue-route-path//blue"
```

```bash
# Green app
cd ../app_green
terragrunt import 'kubernetes_namespace.app' 'green'
terragrunt import 'kubernetes_config_map.html' 'green/green-html'
terragrunt import 'kubernetes_deployment.app' 'green/green-app'
terragrunt import 'kubernetes_service.app' 'green/green-service'
terragrunt import 'kubectl_manifest.httproute' "gateway.networking.k8s.io/v1//HTTPRoute//green-route//green"
terragrunt import 'kubectl_manifest.httproute_path' "gateway.networking.k8s.io/v1//HTTPRoute//green-route-path//green"
```

> **Tip:** If an app doesn't exist in the cluster, skip its imports and run `terragrunt apply` in that component's directory — Terragrunt will create it from scratch.

### Step 4 — Verify all components

```bash
cd ..  # back to local/kind-cluster/
terragrunt run --all plan
```

All components should show "No changes." If any show drift, adjust the module inputs or resource definitions to match.

### Step 5 — Remove from old state

Now that everything is managed by Terragrunt, remove resources from the old state files:

```bash
# Remove CRDs and remaining resources from infra state
cd ../../../02-deploy/infra
tofu state list | grep -v "^data\." | while read -r resource; do tofu state rm "$resource"; done

# Verify infra state is clean (only data sources should remain)
tofu state list
```

```bash
# Remove from apps state
cd ../apps
tofu state list | grep -v "^data\." | while read -r resource; do tofu state rm "$resource"; done

# Verify apps state is clean (only data sources should remain)
tofu state list
```

> **Tip:** For a more controlled approach, you can use `removed` blocks in the old config (as shown in Phase 4).

### Step 6 — Final validation

```bash
# Old states should be empty (only data sources)
cd ../../../02-deploy/infra
tofu state list
# Should show only data sources (data.http, data.external, data.kubectl_file_documents)

# removing them
tofu state rm 'data.external.host_ip[0]'
tofu state rm 'data.http.gateway_api_crds'
tofu state rm 'data.kubectl_file_documents.gateway_api_crds'
tofu state list
# Should be empty

cd ../apps
tofu state list
# Should show only data sources (data.external.host_ip[0])

# removing it
tofu state rm 'data.external.host_ip[0]'
tofu state list
# Should be empty

# New Terragrunt state should be clean
cd ../../05-terragrunt-migration/local/kind-cluster
terragrunt run --all plan
# Should show "No changes" for all components

# Verify the split state files
tree ../../.tfstate/
```

## Understanding the Split State

After migration, each component has its own isolated state file:

```
.tfstate/
└── local/
    └── kind-cluster/
        ├── app_blue/
        │   └── terraform.tfstate      # Only blue app resources
        ├── app_green/
        │   └── terraform.tfstate      # Only green app resources
        ├── app_red/
        │   └── terraform.tfstate      # Only red app resources
        └── nginx-fabric/
            └── terraform.tfstate      # CRDs + Helm + Gateway + NginxProxy
```

Compare this to Phase 2 where **everything** was in a single `terraform.tfstate` file. Now:

- `terragrunt plan` in `app_red/` only refreshes red's 6 resources — not all 30+
- A broken green app doesn't block deploys to red or blue
- Teams can work on different components simultaneously without state lock conflicts
- Destroying one component doesn't risk the others

The state file location is configured in `root.hcl` using `generate "backend"`:

```hcl
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
```

This generates a `backend.tf` file in each component's working directory. The Terragrunt functions resolve to the correct path:
- `get_parent_terragrunt_dir()` → the `05-terragrunt-migration/` folder
- `path_relative_to_include()` → the component name (e.g., `app_red`, `nginx-fabric`)

> **In production**, you'd replace the local backend with a remote one (S3, GCS, etc.) and each component would have its own state key — same pattern, different storage.

## Understanding the `generate` Blocks

Terragrunt's `generate` blocks in `root.hcl` create files that would otherwise be duplicated across every component:

| Generated File | Purpose | Without Terragrunt |
|---|---|---|
| `backend.tf` | State file location | Copy-pasted in every folder |
| `provider.tf` | Kubernetes/Helm/kubectl config | Copy-pasted in every folder |
| `versions.tf` | Provider version constraints | Copy-pasted in every folder |

When you change a provider version or backend config, you update **one file** (`root.hcl`) and all components inherit the change. Without Terragrunt, you'd update N files manually.

## Understanding the DRY Module

Both `modules/app/` and `modules/nginx-fabric/` are reusable across environments. Each component's `terragrunt.hcl` just passes different inputs:

```hcl
# local/kind-cluster/app_red/terragrunt.hcl
inputs = {
  app_name   = "red"
  app_color  = "#dc3545"
  app_emoji  = "🔴"
  app_path   = "/"
}
```

```hcl
# local/kind-cluster/app_green/terragrunt.hcl
inputs = {
  app_name   = "green"
  app_color  = "#198754"
  app_emoji  = "🟢"
  app_path   = "/"
}
```

The `env.hcl` at the cluster level provides shared config that `root.hcl` reads:

```hcl
# local/kind-cluster/env.hcl
locals {
  environment    = "local"
  cluster_name   = "kind-kind"
  config_context = "kind-kind"
  config_path    = "~/.kube/config"
}
```

This means providers are configured once in `root.hcl` using values from `env.hcl`. Adding a new environment is just creating a new folder with a different `env.hcl`:

```
local/
├── kind-cluster/       # env.hcl → config_context = "kind-kind"
│   ├── nginx-fabric/
│   ├── app_red/
│   └── ...
└── kind-cluster-2/     # env.hcl → config_context = "kind-kind-2"
    ├── nginx-fabric/
    ├── app_red/
    └── ...
```

Same modules, different inputs. No code duplication.

## Benefits Achieved

| Before (Monolithic) | After (Terragrunt) |
|---------------------|---------------------|
| Single state file with all resources | Separate state per component |
| Duplicate code per app | Shared module, DRY inputs |
| One `tofu plan` refreshes everything | `terragrunt plan` per component is fast |
| Team conflicts on state lock | Independent state locks per component |
| One blast radius | Isolated failure domains |
| Provider/backend config duplicated | Single `root.hcl` generates for all |
| Adding a new app = copy 200+ lines of .tf | Adding a new app = one `terragrunt.hcl` with 5 inputs |

## Next Step

Proceed to [06-cleanup](../06-cleanup/) to tear everything down.
