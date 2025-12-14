# Using Kind emulate and test kubernetes

Some simple use tools

## Table of Contents

- [Installation](#kind-installation)
- [Create Cluster](#create-cluster)
- [Create Gateway API Cluster](#create-gateway-api-cluster)
- [Metrics-Server](#metrics-server)
- [Prometheus](#kube-prometheus-stack)
- [Ingress](#nginx-ingress)
- [Gateway API](#gateway-api-with-envoy-gateway)
- [Clean up](#clean-up)

## Kind Installation

[Official documentation an how to use it](https://kind.sigs.k8s.io/)

In my case I'm running a Windows Laptop with [WSL2](https://kind.sigs.k8s.io/docs/user/using-wsl2/), so these are [steps used to install](https://kind.sigs.k8s.io/docs/user/quick-start#installing-from-release-binaries).

```bash
# Get latest version
export kindversion=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/kubernetes-sigs/kind/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v${kindversion}/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v${kindversion}/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

## Enable ipv6 on WSL

If you want to enable ipv6 or dual-stack in your kind cluster, you must first apply these changes in your wsl environment:

To find where is your home folder, type in powershell

```powershell
$HOME
```

create/update your `.wslconfig` file in your home directory.

```bash
[wsl2]
...
networkingMode=mirrored # To enable ipv6
...
[experimental]
hostAddressLoopback=True # allow the Container to connect to the Host, or the Host to connect to the Container, by an IP address that's assigned to the Host
```

You can find more details and other options in the [official documentation](https://learn.microsoft.com/en-us/windows/wsl/wsl-config#configuration-settings-for-wslconfig).

Then restart the wsl

```powershell
wsl --shutdown
```

## Enable ipv6 on Docker Desktop

Similar, you can enable ip6 on your docker desktop by selecting on the top the gear icon (settings) -> Docker Engine then adding updating with this info

```json
{
  ...
  "experimental": true,
  "fixed-cidr-v6": "fd00:ec2::/64",
  "ip6tables": true,
  "ipv6": true
}
```

You can update, with some editor like visual code directly on your home folder

```powershell
cd $HOME/.docker
code .\daemon.json
```

Then restart your docker desktop by selecting on the top the question mark icon -> Restart.

## Create cluster

As you can see in [cluster.yaml file](./kind/cluster.yaml) this cluster has 2 controller and 3 workers and expose ports 80 and 443 on localhost.

It will set some additional parameters in case you want to use [prometheus-operator](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) without failures, add the local registry and enable few [adimission controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)

The API Endpoint will bind ip address of your wsl machine, so it can use other Docker containers to reach it, instead or only default `127.0.0.1`.

To create cluster you can just run

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"; envsubst < cluster.yaml | kind create cluster --config -
```

In this case since I just want to test one service at time, using different uri, I am exposing both ports http (80) and https (443) using a self signed dummy certificate, but you can follow same concepts and expose others.

To dump your configuration in yaml format (json is default)

```bash
kubectl cluster-info dump -o yaml
```

To see the list of admission plugins

```bash
kubectl -n kube-system describe pod kube-apiserver-kind-control-plane | grep admission
```

If you enabled dual stack, you can check using these:

```bash
# show nodes cidrs
kubectl get nodes -o go-template --template='{{range .items}}{{printf "Node : %s\n" .metadata.name}}{{range .spec.podCIDRs}}{{printf "%s\n" .}}{{end}}{{"\n"}}{{end}}'
# show node ips
kubectl get nodes -o go-template --template='{{range .items}}{{printf "Node : %s\n" .metadata.name}}{{
range .status.addresses}}{{printf "%s: %s\n" .type .address}}{{end}}{{"\n"}}{{end}}'
# show pod ips
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}} : {{range .status.podIPs}}{{printf "%s " .ip}}{{end}}{{"\n"}}{{end}}' -A
```

To test connectivity from ipv6 in a interative session

```bash
kubectl run -i --tty --rm debug --image=busybox --restart=Never -- sh
```

Inside of your pod

```bash
ifconfig
ping -6 www.google.com
```

To clean up just use `exit`

Other examples can be found on [official documentation](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_run/#examples)

## Create Gateway API Cluster

If you want to use Gateway API with Envoy Gateway instead of nginx ingress, you can use the [cluster-gateway.yaml](./cluster-gateway.yaml) configuration file. This cluster configuration is optimized for Gateway API and includes port mappings for LoadBalancer services.

The main differences from the standard cluster:
- Includes port mapping for Gateway API LoadBalancer services
- Optimized for use with cloud-provider-kind and LoadBalancer port mapping

To create the Gateway API cluster:

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"; envsubst < cluster-gateway.yaml | kind create cluster --config -
```

This cluster configuration exposes:
- Port 80 and 443 for standard HTTP/HTTPS traffic
- Port 8080 mapped to NodePort 30000 for Gateway API services

**Note**: This cluster configuration is specifically designed for Gateway API usage and requires cloud-provider-kind with LoadBalancer port mapping enabled.

## Local Registry

Following the instructions from [kind documentation](https://kind.sigs.k8s.io/docs/user/local-registry/)

Execute this in your WSL (ubuntu in my case) to start the registry container

```bash
set -o errexit
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:2
fi
```

Then to fix the map from localhost to our registry name inside of our cluster execute this

```bash
reg_name='kind-registry'
reg_port='5001'
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done
```

You can check if execution was complete using

```bash
or node in $(kind get nodes | grep -v load); do docker exec "${node}" cat "${REGISTRY_DIR}/hosts.toml";done
```

To connect the registry to the cluster network

```bash
reg_name='kind-registry'
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi
```

You can check if execution was complete using

```bash
docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}"
```

To complete with the document of the local registry, according to [standard](https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry?ref=hackernoon.com#kep-1755-standard-for-communicating-a-local-registry)

```bash
reg_port='5001'
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
```

You can check if execution was complete using

```bash
kubectl -n kube-public get configmaps local-registry-hosting
```

To test you can use this

```bash
# pull a test image from internet to your docker local
docker pull gcr.io/google-samples/hello-app:1.0
# retag it to your local registry
docker tag gcr.io/google-samples/hello-app:1.0 localhost:5001/hello-app:1.0
# push to local registry
docker push localhost:5001/hello-app:1.0
# run a pod in your kind
kubectl run hello --image=localhost:5001/hello-app:1.0
# check if your pod is running
kubectl get pod -o wide
```

It will show you like this

```bash
NAME    READY   STATUS    RESTARTS   AGE   IP           NODE          NOMINATED NODE   READINESS GATES
hello   1/1     Running   0          11s   10.244.3.5   kind-worker   <none>           <none>
```

You can see other examples in our [helm page](../helm/)

To clean up

```bash
kubectl delete pods hello
```

## metrics-server

Metrics Server collects resource metrics from Kubelets and exposes them in Kubernetes apiserver through Metrics API for use by Horizontal Pod Autoscaler and Vertical Pod Autoscaler. Metrics API can also be accessed by kubectl top, making it easier to debug autoscaling pipelines.

[Official Documentation](https://kubernetes-sigs.github.io/metrics-server/) or in their [Github](https://github.com/kubernetes-sigs/metrics-server)

```bash
helm upgrade --install --namespace kube-system \
 --repo https://kubernetes-sigs.github.io/metrics-server/ metrics-server metrics-server \
 --set args[0]=--kubelet-insecure-tls
```

You can check if execution was complete using

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/instance=metrics-server
```

## kube-prometheus-stack

Before install nginx-ingress, you can now install [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) using helm.

```bash
helm upgrade --install --wait --timeout 15m   --namespace monitoring --create-namespace   --repo https://prometheus-community.github.io/helm-charts   prometheus-stack kube-prometheus-stack -f prometheus-values.yaml
```

## nginx Ingress

Use Ingress so you can test access to your applications or prometheus without any manual steps using this:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install --namespace ingress-nginx --create-namespace \
ingress-nginx ingress-nginx/ingress-nginx \
--values https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/hack/manifest-templates/provider/kind/values.yaml \
--set controller.nodeSelector."kubernetes\.io/hostname"=kind-control-plane \
--set controller.extraArgs.publish-status-address="host.docker.internal" \
--set controller.metrics.enabled=true \
--set controller.metrics.serviceMonitor.enabled=true \
--set controller.metrics.serviceMonitor.additionalLabels.release="prometheus-stack" \
--set-string controller.podAnnotations."prometheus\.io/scrape"="true" \
--set-string controller.podAnnotations."prometheus\.io/port"="10254"
```

or remove the latest 5 lines related to metrics and prometheus if you don't want to use it.

**PS**: As you can see in the [nginx helm documentation](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx) we are using a [values.yaml file](https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/hack/manifest-templates/provider/kind/values.yaml) already set to work on kind environment, additionally we are enabling metrics service and Service Monitor, so you can see ingress-nginx metrics on prometheus as well as `nodeSelector` property and Annotations for the controller as described in [nginx docummentation](https://kubernetes.github.io/ingress-nginx/user-guide/monitoring/) to expose services on localhost without any manual configuration.

Now you will have access to main dashboards exposed:

- [grafana](http://host.docker.internal/grafana) - default user: `admin`, password: `prom-operator`
- [prometheus](http://host.docker.internal/prometheus)
- [alertmanager](http://host.docker.internal/alertmanager)

If you enabled the [*.docker.internal](https://docs.docker.com/desktop/setup/install/windows-permission-requirements/) on Docker Settings -> General "Add the *.docker.internal names to the host's /etc/hosts file (Requires password)", then you can access using name like `http://host.docker.internal/grafana`, `http://host.docker.internal/prometheus` or `http://host.docker.internal/alertmanager`.

*Note*: If you try to access `http://127.0.0.1/` or `http://host.docker.internal/` it will fail (404) since the idea is that you can use this path and all others during your tests.

You can add nginx official dashboards following their [documentation](https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/monitoring.md#connect-and-view-grafana-dashboard)

## Gateway API with Envoy Gateway

Gateway API is the next-generation ingress API for Kubernetes, providing more advanced routing capabilities than traditional Ingress. This setup uses Envoy Gateway as the Gateway controller and cloud-provider-kind for LoadBalancer service support.

**Prerequisites**: 
- Use the [cluster-gateway.yaml](./cluster-gateway.yaml) configuration when creating your kind cluster
- Ensure you have the Gateway API cluster running (see [Create Gateway API Cluster](#create-gateway-api-cluster))

### Install Gateway API CRDs

First, install the Gateway API Custom Resource Definitions:

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

### Install Envoy Gateway

Install Envoy Gateway as the Gateway controller:

```bash
kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.6.1/install.yaml --force-conflicts
```

Wait for Envoy Gateway to be ready:

```bash
kubectl get pods -n envoy-gateway-system
```

### Create Gateway Class

Create the Gateway Class that Envoy Gateway will manage:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF
```

### Start Cloud Provider Kind

For LoadBalancer services to work properly in WSL2 environment, start cloud-provider-kind with LoadBalancer port mapping enabled:

```bash
docker run -d --rm --name cloud-provider-kind --network kind -v /var/run/docker.sock:/var/run/docker.sock registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.4.0 --enable-lb-port-mapping
```

**Important**: The `--enable-lb-port-mapping` flag is crucial for LoadBalancer services to get external IPs and be accessible from localhost.

### Deploy HTTPRoute Example

You can now deploy HTTPRoute resources instead of Ingress. Here's an example that creates a red-blue service routing:

```bash
kubectl apply -f ../examples/ingress/red-blue-httproute.yaml
```

### Check Gateway Status

Verify that your Gateway is programmed and has an external IP:

```bash
kubectl get gateway -n red-blue-httproute
kubectl get svc -n envoy-gateway-system
```

### Access Your Services

With cloud-provider-kind running with `--enable-lb-port-mapping`, your Gateway services will be accessible on dynamically assigned localhost ports. Check the load balancer container ports:

```bash
docker ps | grep kindccm
```

You'll see output like:
```
2ebb8bbbe20b   envoyproxy/envoy:v1.30.1   ...   0.0.0.0:52324->80/tcp, 0.0.0.0:52682->10000/tcp   kindccm-...
```

Access your services using the mapped ports:
- HTTP traffic: `http://localhost:52324/red` and `http://localhost:52324/blue`
- Admin interface: `http://localhost:52682/`

### Gateway API Benefits

Gateway API provides several advantages over traditional Ingress:

- **Advanced routing**: Header-based routing, traffic splitting, and more
- **Better resource model**: Separate concerns between infrastructure and application teams
- **Extensibility**: Support for custom filters and policies
- **Type safety**: Strongly typed API with better validation
- **Multi-protocol support**: HTTP, HTTPS, TCP, UDP, and more

### Troubleshooting

If LoadBalancer services remain in `<pending>` state:

1. Ensure cloud-provider-kind is running with the correct flags
2. Check cloud-provider-kind logs: `docker logs cloud-provider-kind`
3. Verify the cluster was created with `cluster-gateway.yaml`

If you can't access services from localhost:

1. Check the dynamically assigned ports: `docker ps | grep kindccm`
2. Ensure the Gateway has an external IP: `kubectl get gateway -A`
3. Verify HTTPRoute is accepted: `kubectl get httproute -A`

### Clean up Cloud Provider Kind

To stop the cloud-provider-kind controller:

```bash
docker stop cloud-provider-kind
```

## clean up

To clean up you can remove using this

```bash
kind delete cluster
```
