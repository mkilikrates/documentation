# Phase 1 — Bootstrap the Kind Cluster

Create a single-node Kind cluster with port mappings for NGINX Gateway Fabric.

> For more details on Kind cluster configuration, dual-stack networking, and local registries, see [Docker/k8s/kind-cluster](../../Docker/k8s/kind-cluster/).

## Create the Cluster

> **WSL2 note:** The configs use `iptables` proxy mode for maximum compatibility. If you're on a native Linux system with kernel modules like `ip_vs` loaded, you can switch to `ipvs` mode for better performance. The `nftables` mode (default in newer Kubernetes) requires kernel modules not present in the standard WSL2 kernel.

### IPv4 Only

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < kind-config-ipv4.yaml | kind create cluster --config -
```

### Dual-Stack (IPv4 + IPv6)

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < kind-config-dualstack.yaml | kind create cluster --config -
```

## Verify

```bash
kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl get nodes
kubectl cluster-info
```

Ensure the node is `Ready` before proceeding — the cluster needs a moment to stabilize its internal networking after creation.

Expected output:

```
NAME                 STATUS   ROLES           AGE   VERSION
kind-control-plane   Ready    control-plane   30s   v1.x.x
```

## Port Mapping Summary

| Protocol | Container Port | Host Port (IPv4) | Host Port (IPv6) | Purpose |
|----------|---------------|-------------------|-------------------|---------|
| TCP | 31437 | 80 | 8080 | HTTP traffic |
| TCP | 31438 | 443 | 8443 | HTTPS traffic |

These ports are used by NGINX Gateway Fabric's NodePort service to expose traffic to the host.

## Next Step

Proceed to [02-deploy](../02-deploy/) to deploy NGINX Gateway Fabric and applications using OpenTofu.
