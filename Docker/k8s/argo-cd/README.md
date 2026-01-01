# Using argo-cd as gitops

Some simple use tools

## Table of Contents

- [Installation](#installation)
- [Clean up](#clean-up)

## Installation

[Official documentation an how to use it](https://argo-cd.readthedocs.io/en/stable/)

In this example the installation will be executed using [helm](https://helm.sh/).

*Basic installation*: This will only install and expose it on path `/argo-cd` as http only, disabling https since this is a local test.

```bash
helm upgrade --install \
--repo https://argoproj.github.io/argo-helm \
argo-cd argo-cd --namespace argocd --create-namespace \
--set configs.params."server\.insecure"=true \
--set configs.params."server\.basehref"="/argo-cd" \
--set configs.params."server\.rootpath"="/argo-cd" \
--set global.domain="" \
--set server.ingress.enabled=true \
--set server.ingress.ingressClassName="nginx" \
--set server.ingress.annotations."nginx\.ingress\.kubernetes\.io/backend-protocol"="HTTP" \
--set server.ingress.path="/argo-cd" \
--set server.ingress.tls=false
```

Using api gateway [nginx-fabric](../nginx-fabric/) it will use this instead:

```bash
# create namespace with api-gateway tag for use the shared gateway
kubectl apply -f namespaces.yaml
# install using api-gateway(nginx-fabric)
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < argocd-apigw-values.yaml | helm upgrade --install --wait --timeout 15m   --namespace argocd --repo https://argoproj.github.io/argo-helm argo-cd argo-cd -f -
```

If you want to monitor using [prometheus operator](https://github.com/prometheus-operator/prometheus-operator?tab=readme-ov-file#helm-chart) then you can enable metrics and use serviceMonitor.

*Note*: That each internal service must be enabled according to your use case, the full version will be like this:

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argo-cd argo/argo-cd --namespace argocd --create-namespace \
--set configs.params."server\.insecure"=true \
--set configs.params."server\.basehref"="/argo-cd" \
--set configs.params."server\.rootpath"="/argo-cd" \
--set global.domain="" \
--set server.ingress.enabled=true \
--set server.ingress.ingressClassName="nginx" \
--set server.ingress.annotations."nginx\.ingress\.kubernetes\.io/backend-protocol"="HTTP" \
--set server.ingress.path="/argo-cd" \
--set server.ingress.tls=false \
--set server.metrics.enabled=true \
--set server.metrics.serviceMonitor.enabled=true \
--set server.metrics.serviceMonitor.namespace=monitoring \
--set server.metrics.serviceMonitor.additionalLabels.release="prometheus-stack" \
--set controller.metrics.enabled=true \
--set controller.metrics.serviceMonitor.enabled=true \
--set controller.metrics.serviceMonitor.additionalLabels.release="prometheus-stack" \
--set redis.exporter.enabled=true \
--set redis.metrics.enabled=true \
--set redis.metrics.serviceMonitor.enabled=true \
--set redis.metrics.serviceMonitor.namespace=monitoring \
--set redis.metrics.serviceMonitor.additionalLabels.release="prometheus-stack" \
--set repoServer.metrics.enabled=true \
--set repoServer.metrics.serviceMonitor.enabled=true \
--set repoServer.metrics.serviceMonitor.namespace=monitoring \
--set repoServer.metrics.serviceMonitor.additionalLabels.release="prometheus-stack" \
--set dex.metrics.enabled=true \
--set dex.metrics.serviceMonitor.enabled=true \
--set dex.metrics.serviceMonitor.namespace=monitoring \
--set dex.metrics.serviceMonitor.additionalLabels.release="prometheus-stack" \
--set applicationSet.metrics.enabled=true \
--set applicationSet.metrics.serviceMonitor.enabled=true \
--set applicationSet.metrics.serviceMonitor.namespace=monitoring \
--set applicationSet.metrics.serviceMonitor.additionalLabels.release="prometheus-stack" \
--set notifications.metrics.enabled=true \
--set notifications.metrics.serviceMonitor.enabled=true \
--set notifications.metrics.serviceMonitor.namespace=monitoring \
--set notifications.metrics.serviceMonitor.additionalLabels.release="prometheus-stack"
```

using api-gateway(nginx-fabric) uncomment the metrics service in the file.

More information about other options can be checked in the official [helm chart docummentation](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd#general-parameters).

Now you can get the random password generated during installation

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d;echo
```

Finally you can access using your browser

### using ingress

- [argo-cd](http://127.0.0.1:/argo-cd) 

 or can test using curl

```bash
curl http://127.0.0.1:/argo-cd
```

### using api-gateway(nginx-fabric)

test using curl

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
curl http://argocd.$MY_PRIVATE_IP.nip.io:8080/
echo http://argocd.$MY_PRIVATE_IP.nip.io:8080/
# if using cert-manager
curl -k https://argocd.$MY_PRIVATE_IP.nip.io:8443/
echo https://argocd.$MY_PRIVATE_IP.nip.io:8443/
```

*PS if you are using ingress*: After you logon, the redirect will fail sending you to `http://127.0.0.1/argo-cd/argo-cd/applications` but you can just go to the right path `http://127.0.0.1/argo-cd/applications`

If you are using prometheus, you can import official dashboard from [github](https://github.com/argoproj/argo-cd/blob/master/examples/dashboard.json)

## clean up

To clean up you can remove using this

```bash
helm -n argocd uninstall argo-cd
kubectl delete namespaces argocd
```
