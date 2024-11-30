# Using Kind emulate and test kubernetes

Some simple use tools

## Table of Contents

- [Installation](#kind-installation)
- [Create Cluster](#create-cluster)
- [Ingress](#ingress)
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

## Ingress

In my case since I just want to test one service at time, I am exposing only port http (80), but you can follow same concepts and expose others.

If you want to use Ingress, you can apply this:

```bash
kubectl apply -f deploy-ingress-nginx.yaml
```

**PS**: This file was changed following the [documentation](https://kind.sigs.k8s.io/docs/user/ingress/#option-2-extraportmapping) to add `nodeSelector` property.

## clean up

To clean up you can remove using this

```bash
kind delete cluster
```
