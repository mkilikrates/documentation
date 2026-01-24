# Using Open Source Kind with Calico CNI

If you want to test network policies with kind, this will hows how to combine it with calico CNI.

## Table of Contents

- [Enable ipv6 on WSL](#enable-ipv6-on-wsl)
- [Enable ipv6 on Docker Desktop](#enable-ipv6-on-docker-desktop)
- [Installation](#kind-installation)
- [Create Cluster](#create-cluster)
- [Clean up](#clean-up)

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

## Create cluster

To create cluster you can just run

```bash
# ipv4 cluster
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"; envsubst < calico_cluster.yaml | kind create cluster --config -
# dualstack cluster
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"; envsubst < calico_cluster_dual.yaml | kind create cluster --config -
```

You can notice that since we disable the default cni (kindnet) the nodes are not `Ready`.

```bash
kubectl get nodes -o wide
NAME                 STATUS     ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION                     CONTAINER-RUNTIME
kind-control-plane   NotReady   control-plane   25s   v1.35.0   172.18.0.4    <none>        Debian GNU/Linux 12 (bookworm)   6.6.87.2-microsoft-standard-WSL2   containerd://2.2.0
kind-worker          NotReady   <none>          14s   v1.35.0   172.18.0.3    <none>        Debian GNU/Linux 12 (bookworm)   6.6.87.2-microsoft-standard-WSL2   containerd://2.2.0
kind-worker2         NotReady   <none>          14s   v1.35.0   172.18.0.2    <none>        Debian GNU/Linux 12 (bookworm)   6.6.87.2-microsoft-standard-WSL2   containerd://2.2.0
```

## Install Calico 

According to [documentation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind)


### Ipv4 only

```bash
# Get latest version
export calicoversion=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/projectcalico/calico/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/v${calicoversion}/manifests/calico.yaml"
```

You can wait until they are ready

```bash
kubectl wait --for=condition=Ready=true node/kind-control-plane --timeout=300s
#or repeat the check on nodes
kubectl get nodes -o wide
NAME                 STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION                     CONTAINER-RUNTIME
kind-control-plane   Ready    control-plane   5m5s    v1.35.0   172.18.0.4    <none>        Debian GNU/Linux 12 (bookworm)   6.6.87.2-microsoft-standard-WSL2   containerd://2.2.0
kind-worker          Ready    <none>          4m54s   v1.35.0   172.18.0.3    <none>        Debian GNU/Linux 12 (bookworm)   6.6.87.2-microsoft-standard-WSL2   containerd://2.2.0
kind-worker2         Ready    <none>          4m54s   v1.35.0   172.18.0.2    <none>        Debian GNU/Linux 12 (bookworm)   6.6.87.2-microsoft-standard-WSL2   containerd://2.2.0
```

### Dual-stack (Recommended for IPv6)

**Important**: If you enabled IPv6 on Docker Desktop, use this method instead of the basic installation above.

#### Step 1: Download and Configure Calico Manifest

```bash
# Get latest version
export calicoversion=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/projectcalico/calico/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
curl -Lo calico.yaml "https://raw.githubusercontent.com/projectcalico/calico/v${calicoversion}/manifests/calico.yaml"
```

#### Step 2: Configure IPAM for Dual-stack

Update the IPAM configuration in the calico.yaml file:

```bash
# Update IPAM configuration for dual-stack
sed -i '/"ipam": {/,/}/c\          "ipam": {\n              "type": "calico-ipam",\n              "assign_ipv4": "true",\n              "assign_ipv6": "true"\n          },' calico.yaml
```

#### Step 3: Install yq (if not already installed)

```bash
export yqversion=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/mikefarah/yq/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./yq "https://github.com/mikefarah/yq/releases/download/v${yqversion}/yq_linux_arm64"
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./yq "https://github.com/mikefarah/yq/releases/download/v${yqversion}/yq_linux_amd64"
chmod +x ./yq
sudo mv ./yq /usr/local/bin/yq
```

#### Step 4: Configure Calico DaemonSet for IPv6

```bash
yq eval '
(select(.kind == "DaemonSet" and .metadata.name == "calico-node") | .spec.template.spec.containers[] | select(.name == "calico-node") | .env[] | select(.name == "FELIX_IPV6SUPPORT") | .value) = "true" |
(select(.kind == "DaemonSet" and .metadata.name == "calico-node") | .spec.template.spec.containers[] | select(.name == "calico-node") | .env) += [
  {"name": "IP6", "value": "autodetect"},
  {"name": "CALICO_IPV6POOL_CIDR", "value": "fd00:10:244::/56"},
  {"name": "CALICO_IPV6POOL_NAT_OUTGOING", "value": "true"}
]
' -i calico.yaml
```

#### Step 5: Apply Calico Configuration

```bash
kubectl create -f calico.yaml
rm calico.yaml
```

**Note**: I'm keeping a version of the [calico.yaml](calico.yaml) in this repo, so you can check the differences in case the commands fail due some change in the latest version.

#### Step 6: Wait for Calico to be Ready

```bash
kubectl wait --for=condition=Ready=true node/kind-control-plane --timeout=300s
```

#### Step 7: Verify Installation

Check that nodes are ready and have both IPv4 and IPv6 addresses:

```bash
kubectl get nodes -o wide
```

you can check using these:

```bash
# wait until node is ready
kubectl wait --for=condition=Ready=true node/kind-control-plane
# show nodes cidrs
kubectl get nodes -o go-template --template='{{range .items}}{{printf "Node : %s\n" .metadata.name}}{{range .spec.podCIDRs}}{{printf "%s\n" .}}{{end}}{{"\n"}}{{end}}'
# show node ips
kubectl get nodes -o go-template --template='{{range .items}}{{printf "Node : %s\n" .metadata.name}}{{
range .status.addresses}}{{printf "%s: %s\n" .type .address}}{{end}}{{"\n"}}{{end}}'
# show pod ips
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}} : {{range .status.podIPs}}{{printf "%s " .ip}}{{end}}{{"\n"}}{{end}}' -A
```

Test IPv6 connectivity:

```bash
kubectl run test-ipv6 --image=busybox --rm -it --restart=Never -- ping -c 3 -6 2001:4860:4860::8888
```

To test connectivity from ipv6 in a interative session

```bash
kubectl run -i --tty --rm debug --image=busybox --restart=Never -- sh
```

Inside of your pod

```bash
ifconfig
ping -c3 -4 www.google.com # ipv4 test
ping -c3 -6 www.google.com # ipv6 test
```

To clean up just use `exit`

Other examples can be found on [official documentation](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_run/#examples)

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
for node in $(kind get nodes | grep -v load); do docker exec "${node}" cat "${REGISTRY_DIR}/hosts.toml";done
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

## Delete cluster

```bash
kind delete cluster
```
