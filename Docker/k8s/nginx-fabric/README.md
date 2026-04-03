# NGINX Gateway Fabric

Deploy [NGINX Gateway Fabric](https://github.com/nginx/nginx-gateway-fabric) as a Gateway API implementation on kind.

## Prerequisites

- A running kind cluster with `extraPortMappings` on the control-plane node (ports 31437 and 31438)
- [cert-manager](../cert-manager/) installed (for TLS support)
- Control-plane taint removed if using a multi-node cluster:

```bash
kubectl taint nodes kind-control-plane node-role.kubernetes.io/control-plane:NoSchedule-
```

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

The gateway service uses NodePort on ports 31437 (HTTP → 8080 on host) and 31438 (HTTPS → 8443 on host).
The controller is pinned to the control-plane node via `nodeSelector`.

Check deployment:

```bash
kubectl wait --timeout=5m -n nginx-gateway deployment/ngf-nginx-gateway-fabric --for=condition=Available
kubectl -n nginx-gateway get pods -o wide
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

### HTTP only

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < shared-gateway.yaml | kubectl apply -f -
```

### HTTP + HTTPS/TLS

Install [cert-manager](../cert-manager/) first, then:

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < shared-gateway-tls.yaml | kubectl apply -f -
```

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

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < app.yaml | kubectl apply -f -
```

### Check the app

```bash
kubectl -n red-blue-nginx-fab get pods
kubectl -n red-blue-nginx-fab get services
kubectl -n red-blue-nginx-fab describe httproutes
```

### Test HTTP

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
curl http://red-blue.$MY_PRIVATE_IP.nip.io:8080/red;echo
curl http://red-blue.$MY_PRIVATE_IP.nip.io:8080/blue;echo
```

### Test HTTPS

```bash
curl -k https://red-blue.$MY_PRIVATE_IP.nip.io:8443/red;echo
curl -k https://red-blue.$MY_PRIVATE_IP.nip.io:8443/blue;echo
```

### Check gateway service

```bash
kubectl -n nginx-gateway get svc nginx-shared-gateway-nginx
```

## Clean up

### Remove test application

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < app.yaml | kubectl delete -f -
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
