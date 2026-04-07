# NGINX Gateway Fabric

Deploy [NGINX Gateway Fabric](https://github.com/nginx/nginx-gateway-fabric) as a Gateway API implementation on kind.

## Prerequisites

- A running kind cluster with `extraPortMappings` on the control-plane node
  - IPv4 only: ports 31437→80 and 31438→443 with `listenAddress: "0.0.0.0"`
  - Dual-stack: additionally ports 31437→8080 and 31438→8443 with `listenAddress: "::"` (kind doesn't allow the same host port for both IPv4 and IPv6, so IPv6 uses different host ports)
- [cert-manager](../cert-manager/) installed (for TLS support)
- Control-plane taint removed if using a multi-node cluster:

```bash
kubectl taint nodes kind-control-plane node-role.kubernetes.io/control-plane:NoSchedule-
```

or check on [multinode_cluster](../kind-cluster/multinode_cluster.yaml) `kubeadmConfigPatches` for both `kind-control-plane` nodes.

```bash
kubectl get nodes -o json | jq '.items[].spec.taints'
```

You should see `null` for all of them

## Install Gateway API CRDs

```bash
export gatewayapiversion=$(curl -Ls -o /dev/null -w %{url_effective} \
  https://github.com/nginx/nginx-gateway-fabric/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
kubectl kustomize \
  "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v${gatewayapiversion}" \
  | kubectl apply -f -
```

## Install NGINX Gateway Fabric using Helm

```bash
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --create-namespace -n nginx-gateway \
  --set nginx.service.type=NodePort \
  --set-json 'nginx.service.nodePorts=[{"name":"http","port":31437,"listenerPort":80},{"name":"https","port":31438,"listenerPort":443}]' \
  --set-json 'nginxGateway.nodeSelector={"kubernetes.io/hostname":"kind-control-plane"}'
```

The gateway service uses NodePort on ports 31437 (HTTP) and 31438 (HTTPS), mapped to host ports 80/443 (IPv4) and 8080/8443 (IPv6).
The controller is pinned to the control-plane node via `nodeSelector`.

Check deployment:

```bash
kubectl wait --timeout=5m -n nginx-gateway deployment/ngf-nginx-gateway-fabric --for=condition=Available
kubectl -n nginx-gateway get pods -o wide
```

### Dual-stack: patch the controller service

The NGF helm chart doesn't expose `ipFamilyPolicy` for the controller service. On a dual-stack cluster, patch it after install:

```bash
kubectl -n nginx-gateway patch svc ngf-nginx-gateway-fabric --type=merge \
  -p '{"spec":{"ipFamilyPolicy":"PreferDualStack","ipFamilies":["IPv4","IPv6"]}}'
```

## Pin the data plane to the control-plane node

NGINX Gateway Fabric creates a separate data plane deployment when you create a Gateway resource. By default it can schedule on any node, but in kind only the control-plane has Docker port mappings to the host. The data plane must run there.

NGINX Gateway Fabric also sets `externalTrafficPolicy: Local` on the gateway service (and reconciles it back if you change it), which means kube-proxy only forwards NodePort traffic to pods on the same node.

Pin the data plane via the `NginxProxy` resource:

```bash
kubectl -n nginx-gateway patch nginxproxy ngf-proxy-config --type=merge \
  -p '{"spec":{"kubernetes":{"deployment":{"pod":{"nodeSelector":{"kubernetes.io/hostname":"kind-control-plane"}}}}}}'
```

> **Note:** This is a kind-specific constraint. In a real cluster with a LoadBalancer service, traffic would reach any node and `externalTrafficPolicy: Local` would work correctly.

## Create a shared gateway

### IPv4 only — HTTP

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < shared-gateway.yaml | kubectl apply -f -
```

### IPv4 only — HTTP + HTTPS/TLS

Install [cert-manager](../cert-manager/) first, then:

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < shared-gateway-tls.yaml | kubectl apply -f -
```

### Dual-stack (IPv4 + IPv6) — HTTP

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
export MY_GLOBAL_IP6="$(ip -6 addr show $iface scope global | grep -oP '(?<=inet6\s)[0-9a-f:]+(?=/)'| head -1 | tr ':' '-')"
envsubst < shared-gateway-dual.yaml | kubectl apply -f -
```

### Dual-stack (IPv4 + IPv6) — HTTP + HTTPS/TLS

Install [cert-manager](../cert-manager/) first, then:

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
export MY_GLOBAL_IP6="$(ip -6 addr show $iface scope global | grep -oP '(?<=inet6\s)[0-9a-f:]+(?=/)'| head -1 | tr ':' '-')"
envsubst < shared-gateway-tls-dual.yaml | kubectl apply -f -
```

> **Note on dual-stack:** The dual-stack gateway adds IPv6 listeners using `$MY_GLOBAL_IP6.nip.io` hostnames alongside the IPv4 ones. We use a global-scope IPv6 address (not link-local `fe80::`) because link-local addresses require a scope ID (`%eth0`) that DNS and curl can't handle. nip.io requires IPv6 addresses with dashes instead of colons (e.g. `2001-818-c251-2900.nip.io`), so we pipe through `tr ':' '-'`. Services in the app use `ipFamilyPolicy: PreferDualStack` to get both IPv4 and IPv6 ClusterIPs. Requires the kind cluster to have `ipFamily: dual` with separate `extraPortMappings` for IPv4 (`listenAddress: "0.0.0.0"`, ports 80/443) and IPv6 (`listenAddress: "::"`, ports 8080/8443) — kind doesn't support binding the same host port to both address families.
### Verify the gateway

```bash
kubectl -n nginx-gateway get gateway
kubectl -n nginx-gateway get gateway nginx-shared-gateway -o jsonpath='{.spec.listeners[*].hostname}';echo
```

The shared gateway allows multiple applications to attach HTTPRoutes to it — each with different hostnames and routing rules.

### Verify pods are on the control-plane

```bash
kubectl -n nginx-gateway get pods -o wide
```

Both `ngf-nginx-gateway-fabric` and `nginx-shared-gateway-nginx` should be on `kind-control-plane`.

## Deploy test application

### IPv4 only

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < app.yaml | kubectl apply -f -
```

### Dual-stack (IPv4 + IPv6)

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
export MY_GLOBAL_IP6="$(ip -6 addr show $iface scope global | grep -oP '(?<=inet6\s)[0-9a-f:]+(?=/)'| head -1 | tr ':' '-')"
envsubst < app-dual.yaml | kubectl apply -f -
```

### Check the app

```bash
kubectl -n red-blue-nginx-fab get pods
kubectl -n red-blue-nginx-fab get services
kubectl -n red-blue-nginx-fab describe httproutes
```

For dual-stack, verify services have both ClusterIPs:

```bash
kubectl -n red-blue-nginx-fab get svc -o wide
kubectl -n red-blue-nginx-fab get svc red-service -o jsonpath='{.spec.clusterIPs}';echo
```

### Test HTTP (IPv4)

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
curl http://red-blue.$MY_PRIVATE_IP.nip.io:80/red;echo
curl http://red-blue.$MY_PRIVATE_IP.nip.io:80/blue;echo
```

### Test HTTPS (IPv4)

```bash
curl -k https://red-blue.$MY_PRIVATE_IP.nip.io:443/red;echo
curl -k https://red-blue.$MY_PRIVATE_IP.nip.io:443/blue;echo
```

### Test HTTP (IPv6) — dual-stack only

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_GLOBAL_IP6="$(ip -6 addr show $iface scope global | grep -oP '(?<=inet6\s)[0-9a-f:]+(?=/)' | head -1 | tr ':' '-')"
curl -6 http://red-blue.$MY_GLOBAL_IP6.nip.io:8080/red;echo
curl -6 http://red-blue.$MY_GLOBAL_IP6.nip.io:8080/blue;echo
```

### Test HTTPS (IPv6) — dual-stack only

```bash
curl -6 -k https://red-blue.$MY_GLOBAL_IP6.nip.io:8443/red;echo
curl -6 -k https://red-blue.$MY_GLOBAL_IP6.nip.io:8443/blue;echo
```

### Check gateway service

```bash
kubectl -n nginx-gateway get svc nginx-shared-gateway-nginx
```

## Clean up

### Remove test application

IPv4 only:

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < app.yaml | kubectl delete -f -
```

Dual-stack:

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
export MY_GLOBAL_IP6="$(ip -6 addr show $iface scope global | grep -oP '(?<=inet6\s)[0-9a-f:]+(?=/)'| head -1 | tr ':' '-')"
envsubst < app-dual.yaml | kubectl delete -f -
```

### Remove shared gateway

```bash
kubectl -n nginx-gateway delete gateway nginx-shared-gateway
```

### Uninstall NGINX Gateway Fabric

```bash
helm uninstall ngf -n nginx-gateway
```

### Uninstall Gateway API CRDs

```bash
export gatewayapiversion=$(curl -Ls -o /dev/null -w %{url_effective} \
  https://github.com/nginx/nginx-gateway-fabric/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
kubectl kustomize \
  "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v${gatewayapiversion}" \
  | kubectl delete -f -
```
