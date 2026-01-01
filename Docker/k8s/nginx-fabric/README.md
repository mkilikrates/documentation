# NGINX FABRIC

For this example, I'm using the [single_cluster.yaml](../kind-cluster/single_cluster.yaml) file. To use other option you may need add some steps to deploy gateway using nodeselector. It is not my focus on that.

## Install Gateway API CRDs

First, install the Gateway API Custom Resource Definitions:

```bash
export gatewayapiversion=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/nginx/nginx-gateway-fabric/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v${gatewayapiversion}" | kubectl apply -f -
```

## Install NGINX Gateway using Helm

```bash
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway --set nginx.service.type=NodePort --set-json 'nginx.service.nodePorts=[{"name":"http","port":31437,"listenerPort":80},{"name":"https","port":31438,"listenerPort":443}]'
```

**Note:** The gateway service is set to Nodeport listen on port 31437 and 31438

check deployment

```bash
kubectl wait --timeout=5m -n nginx-gateway deployment/ngf-nginx-gateway-fabric --for=condition=Available
kubectl -n nginx-gateway get pods
```

## Create a shared gateway

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"; envsubst < shared-gateway.yaml | kubectl apply -f -
```

check the gateway

```bash
kubectl -n nginx-gateway get gateway
```

**Note:** The advantage of using this shared gateway is that we now can deploy several different hosts and http routing rules for each of them.

you can see it using

```bash
kubectl -n nginx-gateway get gateway nginx-shared-gateway -o jsonpath='{.spec.listeners[].hostname}';echo
```

### install app test

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"; envsubst < app.yaml | kubectl apply -f -
```

### check the app

Note that the gateway service is set to Nodeport listen on port 31437

```bash
kubectl -n red-blue-nginx-fab get pods
kubectl -n red-blue-nginx-fab get services
kubectl -n red-blue-nginx-fab describe httproutes
kubectl -n red-blue-nginx-fab describe gateways
```

### test the app

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
curl http://red-blue.$MY_PRIVATE_IP.nip.io:8080/red;echo
curl http://red-blue.$MY_PRIVATE_IP.nip.io:8080/blue;echo
```

### check gateway service as nodeport

```bash
kubectl -n nginx-gateway get svc nginx-shared-gateway-nginx
```

## clean up

### uninstall app test

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"; envsubst < app.yaml | kubectl delete -f -
```

### remove shared gateway

```bash
kubectl -n nginx-gateway delete gateway nginx-shared-gateway
```

### uninstall nginx fabric

```bash
helm uninstall ngf -n nginx-gateway
```

### uninstall Gateway API CRDs

```bash
export gatewayapiversion=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/nginx/nginx-gateway-fabric/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v${gatewayapiversion}" | kubectl delete -f -
```
