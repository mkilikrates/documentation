## cloud-provider-kind

This will help you to create ingress, load balancer and api gateways without thirdy part (nginx-ingress).

[Official documentation an how to use it](https://kubernetes-sigs.github.io/cloud-provider-kind/).

**PS**: As the [documentation](https://kubernetes-sigs.github.io/cloud-provider-kind/#/user/support/os_support) explains: When you start cloud-provider-kind and create a LoadBalancer service, you will notice that a container named `kindccm-...` is launched within `Docker`. You can access the service by using the port exposed from the container to the host machine with localhost.
 
You can install, download binaries (as I doing here) or use the docker image

```bash
export cloudproviderkindversion=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/kubernetes-sigs/cloud-provider-kind/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./cloud-provider-kind.tar.gz https://github.com/kubernetes-sigs/cloud-provider-kind/releases/download/v${cloudproviderkindversion}/cloud-provider-kind_${cloudproviderkindversion}_linux_amd64.tar.gz
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./cloud-provider-kind.tar.gz https://github.com/kubernetes-sigs/cloud-provider-kind/releases/download/v${cloudproviderkindversion}/cloud-provider-kind_${cloudproviderkindversion}_linux_ard64.tar.gz
tar -xvzf cloud-provider-kind.tar.gz
sudo mv ./cloud-provider-kind /usr/local/bin/cloud-provider-kind
rm cloud-provider-kind.tar.gz
rm LICENSE
rm README.md
```

Then run it

```bash
cloud-provider-kind
```

It will automatically monitor your kind cluster for ingress, load balancer and api gateways, and create/expose resources.

### deploy test app using ingress

```bash
kubectl apply -f ../app-examples/ingress/red-blue-service.yaml
```

#### get the port used by the ingress (kindccm-gw-*)

```bash
docker ps | grep kindccm-gw
or use the cli above to get the container name or id and use in the line bellow
docker inspect kindccm-gw-2fcd1923cf7b | jq '.[].NetworkSettings.Ports'
```

#### test the app

```bash
curl localhost:55583/red
curl localhost:55583/blue
```

### unistall test app using ingress

```bash
kubectl delete -f ../app-examples/ingress/red-blue-service.yaml
```
### deploy test app using api gateway

```bash
kubectl apply -f ../app-examples/httproute/red-blue-httproute-provider-kind.yaml
```

#### get the port used by the api gateway (kindccm-gw-*)

```bash
docker ps | grep kindccm-gw
or use the cli above to get the container name or id and use in the line bellow
docker inspect kindccm-gw-58f2555d9b94 | jq '.[].NetworkSettings.Ports'
```

#### test the app

```bash
curl localhost:55739/red
curl localhost:55739/blue
```

### unistall test app using ingress

```bash
kubectl delete -f ../app-examples/httproute/red-blue-httproute-provider-kind.yaml
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
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"; envsubst < ../nginx-fabric/app.yaml | kubectl apply -f -
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
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v${gatewayapiversion}/deploy/nodeport/deploy.yaml
```

## clean up

### uninstall app test

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"; envsubst < ../nginx-fabric/app.yaml | kubectl delete -f -
```

### remove shared gateway

```bash
kubectl -n nginx-gateway delete gateway nginx-shared-gateway
```

