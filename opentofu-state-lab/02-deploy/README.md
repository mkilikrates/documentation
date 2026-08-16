# Phase 2 — Deploy with OpenTofu

Deploy NGINX Gateway Fabric and colored web applications using OpenTofu. This creates state files that we'll use in subsequent phases.

## Structure

This phase is split into two folders, mirroring how real teams work:

```
02-deploy/
├── infra/    # Platform team: CRDs + NGINX Gateway Fabric + Shared Gateway
└── apps/     # App teams: Red and Blue applications
```

**Why split?** The Gateway API CRDs must exist before apps can create HTTPRoute resources. Splitting into `infra/` and `apps/` reflects real-world practice — a platform team manages the ingress controller and shared gateway, while app teams deploy their services independently.

> **Note:** We use the `alekc/kubectl` provider for Gateway API custom resources (Gateway, HTTPRoute, NginxProxy) instead of the built-in `kubernetes_manifest`. The reason: `kubernetes_manifest` validates that CRDs exist at plan time — before anything is applied. `kubectl_manifest` only validates at apply time, which avoids chicken-and-egg issues.

## Deploy Infrastructure

```bash
cd 02-deploy/infra

# Initialize providers
tofu init

# Preview what will be created
tofu plan

# Apply (type 'yes' when prompted)
tofu apply
```

> **IP Detection:** The host IP is auto-detected from your default network interface. To override: `export TF_VAR_private_ip="your.ip.here"`
> **Other Options:** You can check [Official Documentation](https://opentofu.org/docs/cli/commands/plan/#other-options) to see additional options, for instance usage of `-concise` to show a compact output.

### Verify NGINX Gateway Fabric

```bash
kubectl wait --timeout=5m -n nginx-gateway deployment/ngf-nginx-gateway-fabric --for=condition=Available
kubectl -n nginx-gateway get pods -o wide
kubectl -n nginx-gateway get gateway
```

## Deploy Applications

```bash
cd ../apps  # or cd 02-deploy/apps from the lab root

# Initialize providers
tofu init

# Preview
tofu plan

# Apply
tofu apply
```

### Check Applications

```bash
kubectl -n red get pods
kubectl -n red get services
kubectl -n blue get pods
kubectl -n blue get services
kubectl get httproutes -A
```

### Test in Browser

Get your IP and open in a browser:

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"

# Host-based routing (each app has its own hostname)
echo "Red app:  http://red.$MY_PRIVATE_IP.nip.io"
echo "Blue app: http://blue.$MY_PRIVATE_IP.nip.io"

# Path-based routing (shared hostname, different paths)
echo "Red app:  http://apps.$MY_PRIVATE_IP.nip.io/red"
echo "Blue app: http://apps.$MY_PRIVATE_IP.nip.io/blue"
```

Both work simultaneously — same backend, two routing strategies.

### Test with curl

```bash
# Host-based
curl http://red.$MY_PRIVATE_IP.nip.io
curl http://blue.$MY_PRIVATE_IP.nip.io

# Path-based
curl http://apps.$MY_PRIVATE_IP.nip.io/red
curl http://apps.$MY_PRIVATE_IP.nip.io/blue
```

## Inspect the State Files

Now is a good time to explore the state files:

```bash
# Infrastructure state (from 02-deploy/infra/)
tofu state list

# Apps state (from 02-deploy/apps/)
tofu state list

# Show details of a specific resource
tofu state show kubernetes_deployment.red

# View the raw state file (it's just JSON)
cat terraform.tfstate | python3 -m json.tool | head -50
```

## Understanding the State

The state file (`terraform.tfstate`) is a JSON file that maps your `.tf` configuration to real infrastructure. It tracks:

- **Resource identifiers** — how OpenTofu finds each resource in the cluster
- **Current attributes** — the last-known state of each resource
- **Dependencies** — which resources depend on others
- **Metadata** — provider versions, serial number (increments on each change)

> **Important:** The state file is the single source of truth for OpenTofu. If it gets out of sync with reality, you'll see drift.

## Next Step

Proceed to [03-drift-and-refresh](../03-drift-and-refresh/) to introduce changes outside OpenTofu and learn how to detect and handle drift.
