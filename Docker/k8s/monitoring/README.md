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

There are 2 versions:
- **Using nginx-ingress**: [prometheus-values.yaml](./prometheus-values.yaml)
- **Using api-gateway(nginx)**: [prometheus-apigw-values.yaml](./prometheus-apigw-values.yaml)

Helm chart [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) and official documentation.


- installing with nginx-ingress

```bash
helm upgrade --install --wait --timeout 15m   --namespace monitoring --create-namespace   --repo https://prometheus-community.github.io/helm-charts   prometheus-stack kube-prometheus-stack -f prometheus-values.yaml
```

- installing with api-gateway([nginx-fabric](../nginx-fabric/))


```bash
# create namespace with api-gateway tag for use the shared gateway
kubectl apply -f namespaces.yaml
# install using api-gateway(nginx-fabric)
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"; envsubst < prometheus-apigw-values.yaml | helm upgrade --install --wait --timeout 15m   --namespace monitoring --repo https://prometheus-community.github.io/helm-charts   prometheus-stack kube-prometheus-stack -f -
```

### getting admin password of grafana

```bash
kubectl --namespace monitoring get secrets prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

### checking pods

```bash
kubectl --namespace monitoring get pods
```

### get urls

```bash
kubectl --namespace monitoring get httproute
export iface=$(route | grep '^default' | grep -o '[^ ]*$');export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
echo prometheus - http://prometheus.$MY_PRIVATE_IP.nip.io:8080/
echo alertmanager - http://alertmanager.$MY_PRIVATE_IP.nip.io:8080/
echo grafana - http://grafana.$MY_PRIVATE_IP.nip.io:8080/
```

Then you can open each of them in your browser

## clean up

```bash
helm -n monitoring uninstall prometheus-stack
kubect delete namespaces monitoring
```
