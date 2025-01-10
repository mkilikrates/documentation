# Using Keda

Some simple use cases

## Table of Contents

- [Installation](#keda-installation)
- [Scaling with cron](#scalling-some-app-using-keda-based-on-cron)
- [Clean up](#clean-up)

## Keda Installation

[Official documentation an how to use it](https://keda.sh/)

Installing using [helm](https://helm.sh/)

```bash
helm upgrade --install \
 --namespace keda --create-namespace \
 --repo https://kedacore.github.io/charts/ \
 keda keda
```

If want get metrics of keda on [prometheus](https://keda.sh/docs/2.16/integrations/prometheus/)

```bash
helm upgrade --install \
 --namespace keda --create-namespace \
 --repo https://kedacore.github.io/charts/ \
 keda keda \
 --set prometheus.metricServer.enabled=true \
 --set prometheus.metricServer.serviceMonitor.enabled=true \
 --set prometheus.metricServer.serviceMonitor.additionalLabels.release="prometheus-stack" \
 --set prometheus.metricServer.podMonitor.enabled=true \
 --set prometheus.operator.enabled=true \
 --set prometheus.operator.serviceMonitor.enabled=true \
 --set prometheus.operator.serviceMonitor.additionalLabels.release="prometheus-stack" \
 --set prometheus.operator.podMonitor.enabled=true \
 --set prometheus.webhooks.enabled=true \
 --set prometheus.webhooks.serviceMonitor.enabled=true \
 --set prometheus.webhooks.serviceMonitor.additionalLabels.release="prometheus-stack" \
 --set prometheus.webhooks.podMonitor.enabled=true
```

Then you can import [dashboard](https://github.com/kedacore/keda/blob/main/config/grafana/keda-dashboard.json) or from [grafana](https://grafana.com/grafana/dashboards/22111-keda-operator/)

## Scalling some app using keda based on cron

For instance, let's use our [examples/initcontainers](../kind/examples/initcontainers/README.md)

```bash
kubectl apply -f ../kind/examples/initcontainers/nginx-busybox-initcontainer.yaml
```

if you are using names `host.docker.internal` and `https` then use this

```bash
kubectl apply -f ../kind/examples/initcontainers/nginx-busybox-initcontainer-https.yaml
```

Then let's scale [number of replicas](cronscale.yaml) from 3 to 10

*Note*: You can adjust cron for the numbers that makes sense for your test, more information [here](https://crontab.guru/)

Official documentation on scale [Deployment](https://keda.sh/docs/1.5/concepts/scaling-deployments/) using [cron](https://keda.sh/docs/2.16/scalers/cron/)

```bash
kubectl apply -f cronscale.yaml
```

To check you can use this

```bash
watch kubectl -n initcontainer get pods
```

## clean up

To clean up you can remove using this

```bash
kubectl delete -f cronscale.yaml
kubectl delete -f ../kind/examples/initcontainers/nginx-busybox-initcontainer.yaml
# uninstall keda
helm -n keda uninstall keda
kubectl delete namespaces keda
```
