# Using Kind emulate and test kubernetes

Some simple use tools

## Table of Contents

- [Installation](#kind-installation)
- [Create Cluster](#create-cluster)
- [Metrics-Server](#metrics-server)
- [Prometheus](#kube-prometheus-stack)
- [Ingress](#nginx-ingress)
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

## Create cluster

As you can see in [cluster.yaml file](./kind/cluster.yaml) this cluster has 1 controller and 3 workers and expose ports 80 on localhost.

It will set some additional parameters in case you want to use [prometheus-operator](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) without failures.

The API Endpoint will bind ip address of your wsl machine, so it can use other Docker containers to reach it, instead or only default `127.0.0.1`.

To create cluster you can just run

```bash
export MY_PRIVATE_IP="$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < cluster.yaml | kind create cluster --config -
```

*PS*: This will export a variable MY_PRIVATE_IP with ip address of your wsl, then it will replace this variable on yaml file that will be used on kind create cluster command.

In this case since I just want to test one service at time, using different uri, I am exposing only port http (80), but you can follow same concepts and expose others.

## metrics-server

Metrics Server collects resource metrics from Kubelets and exposes them in Kubernetes apiserver through Metrics API for use by Horizontal Pod Autoscaler and Vertical Pod Autoscaler. Metrics API can also be accessed by kubectl top, making it easier to debug autoscaling pipelines.

[Official Documentation](https://kubernetes-sigs.github.io/metrics-server/) or in their [Github](https://github.com/kubernetes-sigs/metrics-server)

```bash
helm upgrade --install --namespace kube-system \
 --repo https://kubernetes-sigs.github.io/metrics-server/ metrics-server metrics-server \
 --set args[0]=--kubelet-insecure-tls
```

## kube-prometheus-stack

Before install nginx-ingress, you can now install [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) using helm.

```bash
helm upgrade --install --wait --timeout 15m   --namespace monitoring --create-namespace   --repo https://prometheus-community.github.io/helm-charts   prometheus-stack kube-prometheus-stack -f prometheus-values.yaml
```

## nginx Ingress

Use Ingress so you can test access to your applications or prometheus without any manual steps using this:

```bash
helm upgrade --install --namespace ingress-nginx --create-namespace \
--repo https://kubernetes.github.io/ingress-nginx ingress-nginx ingress-nginx \
--values https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/hack/manifest-templates/provider/kind/values.yaml \
--set controller.metrics.enabled=true \
--set controller.metrics.serviceMonitor.enabled=true \
--set controller.nodeSelector."kubernetes\.io/hostname"=kind-control-plane \
--set controller.metrics.serviceMonitor.additionalLabels.release="prometheus-stack" \
--set-string controller.podAnnotations."prometheus\.io/scrape"="true" \
--set-string controller.podAnnotations."prometheus\.io/port"="10254"
```

**PS**: As you can see in the [nginx helm documentation](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx) we are using a [values.yaml file](https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/hack/manifest-templates/provider/kind/values.yaml) already set to work on kind environment, additionally we are enabling metrics service and Service Monitor, so you can see ingress-nginx metrics on prometheus as well as `nodeSelector` property and Annotations for the controller as described in [nginx docummentation](https://kubernetes.github.io/ingress-nginx/user-guide/monitoring/) to expose services on localhost without any manual configuration.

Now you will have access to main dashboards exposed:

- [grafana](http://127.0.0.1/grafana/) - default user: `admin`, password: `prom-operator`
- [prometheus](http://127.0.0.1/prometheus)
- [alertmanager](http://127.0.0.1/alertmanager)

*Note*: If you try to access `http://127.0.0.1/` it will fail (404) since the idea is that you can use this path and all others during your tests.

You can add nginx official dashboards following their [documentation](https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/monitoring.md#connect-and-view-grafana-dashboard)

## clean up

To clean up you can remove using this

```bash
kind delete cluster
```
