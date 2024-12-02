# Using Kind emulate and test kubernetes

Some simple use tools

## Table of Contents

- [Installation](#kind-installation)
- [Create Cluster](#create-cluster)
- [Ingress](#nginx-ingress)
- [Prometheus](#kube-prometheus-stack)
- [Clean up](#clean-up)

## Kind Installation

[Official documentation an how to use it](https://kind.sigs.k8s.io/)

In my case I'm running a Windows Laptop with [WSL2](https://kind.sigs.k8s.io/docs/user/using-wsl2/), so these are [steps used to install](https://kind.sigs.k8s.io/docs/user/quick-start#installing-from-release-binaries).

```bash
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.25.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.25.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

## Create cluster

As you can see in [cluster.yaml file](./kind/cluster.yaml) this cluster has 1 controller and 3 workers and expose ports 80 on localhost

To create cluster you can just run

```bash
kind create cluster --config cluster.yaml
```

If you prefer to monitor your resources and testes using [prometheus-operator](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack), then use the following line:

```bash
kind create cluster --config cluster-prometheus.yaml
```

In my case since I just want to test one service at time, I am exposing only port http (80), but you can follow same concepts and expose others.

## kube-prometheus-stack

Before install nginx-ingress, you can now install [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) using helm.

```bash
helm upgrade --install --wait --timeout 15m   --namespace monitoring --create-namespace   --repo https://prometheus-community.github.io/helm-charts   prometheus-stack kube-prometheus-stack -f prometheus-values.yaml
```

## nginx Ingress

If you want to use Ingress, you can apply this:

```bash
kubectl apply -f deploy-ingress-nginx.yaml
```

**PS**: This file was changed following the [documentation](https://kind.sigs.k8s.io/docs/user/ingress/#option-2-extraportmapping) to add `nodeSelector` property and Annotations for monitor as described in [nginx docummentation](https://kubernetes.github.io/ingress-nginx/user-guide/monitoring/).

or if you installed the prometheus-cluster, use this version:

```bash
helm upgrade --install --namespace ingress-nginx --create-namespace \
--repo https://kubernetes.github.io/ingress-nginx ingress-nginx ingress-nginx \
--values https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/hack/manifest-templates/provider/kind/values.yaml \
--set controller.metrics.enabled=true \
--set controller.metrics.serviceMonitor.enabled=true \
--set controller.nodeSelector."kubernetes\.io/hostname"=kind-control-plane \
--set controller.metrics.serviceMonitor.additionalLabels.release="prometheus-stack"
```

Now you will have access to main dashboards exposed:

- [grafana](http://127.0.0.1/grafana/) - default user: `admin`, password: `prom-operator`
- [prometheus](http://127.0.0.1/prometheus)
- [alertmanager](http://127.0.0.1/alertmanager)

*Note*: If you try to access `http://127.0.0.1/` it will fail since the idea is that you can use this path in other tests.

## clean up

To clean up you can remove using this

```bash
kind delete cluster
```
