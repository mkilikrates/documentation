# Kubernetes Observability Stack

Full Grafana observability stack on kind: Prometheus (metrics), Loki (logs), Tempo (traces), Alloy (collector), and Grafana (visualization).

## Prerequisites

- A running kind cluster (see [kind-cluster](../kind-cluster/) or [kind-calico](../kind-calico/))
- [NGINX Gateway Fabric](../nginx-fabric/) installed with a shared gateway (for Gateway API access)
- [cert-manager](../cert-manager/) installed (optional, for TLS)
- Helm installed

## metrics-server

Metrics Server collects resource metrics from Kubelets and exposes them in Kubernetes apiserver through Metrics API for use by Horizontal Pod Autoscaler and Vertical Pod Autoscaler. Metrics API can also be accessed by `kubectl top`, making it easier to debug autoscaling pipelines.

[Official Documentation](https://kubernetes-sigs.github.io/metrics-server/) or in their [Github](https://github.com/kubernetes-sigs/metrics-server)

```bash
helm upgrade --install --namespace kube-system \
 --repo https://kubernetes-sigs.github.io/metrics-server/ metrics-server metrics-server \
 --set args[0]=--kubelet-insecure-tls
```

Dual-stack: patch the metrics-server service (helm chart doesn't expose `ipFamilyPolicy`):

```bash
kubectl -n kube-system patch svc metrics-server --type=merge \
  -p '{"spec":{"ipFamilyPolicy":"PreferDualStack","ipFamilies":["IPv4","IPv6"]}}'
```

Verify:

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/instance=metrics-server
kubectl top nodes
```

## kube-prometheus-stack (Prometheus + Grafana + Alertmanager)

There are 2 versions:
- **Using nginx-ingress**: [prometheus-values.yaml](./prometheus-values.yaml)
- **Using Gateway API (nginx-fabric)**: [prometheus-apigw-values.yaml](./prometheus-apigw-values.yaml) — includes Loki and Tempo datasources pre-configured in Grafana

### Install with Gateway API (recommended)

#### IPv4 only

```bash
kubectl apply -f namespaces.yaml
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst '${MY_PRIVATE_IP}' < prometheus-apigw-values.yaml | helm upgrade --install --wait --timeout 15m \
  --namespace monitoring \
  --repo https://prometheus-community.github.io/helm-charts \
  prometheus-stack kube-prometheus-stack -f -
```

#### Dual-stack (IPv4 + IPv6)

```bash
kubectl apply -f namespaces.yaml
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst '${MY_PRIVATE_IP} ${MY_GLOBAL_IP6}' < prometheus-apigw-dual-values.yaml | helm upgrade --install --wait --timeout 15m \
  --namespace monitoring \
  --repo https://prometheus-community.github.io/helm-charts \
  prometheus-stack kube-prometheus-stack -f -
```

### Install with nginx-ingress (legacy)

```bash
helm upgrade --install --wait --timeout 15m \
  --namespace monitoring --create-namespace \
  --repo https://prometheus-community.github.io/helm-charts \
  prometheus-stack kube-prometheus-stack -f prometheus-values.yaml
```

## Loki (Logs)

[Grafana Loki](https://grafana.com/oss/loki/) is a log aggregation system. We deploy it in single-binary mode with filesystem storage — no S3/MinIO needed for a lab.

### IPv4 only

```bash
helm upgrade --install --wait --timeout 10m \
  --namespace monitoring \
  --repo https://grafana.github.io/helm-charts \
  loki loki -f loki-values.yaml
```

### Dual-stack


```bash
helm upgrade --install --wait --timeout 10m \
  --namespace monitoring \
  --repo https://grafana.github.io/helm-charts \
  loki loki -f loki-dual-values.yaml

# Loki Helm chart doesn't support ipFamilyPolicy natively — patch services after install
kubectl -n monitoring get svc -l app.kubernetes.io/name=loki -o name | \
  xargs -I{} kubectl -n monitoring patch {} --type=merge \
  -p '{"spec":{"ipFamilyPolicy":"PreferDualStack","ipFamilies":["IPv4","IPv6"]}}'
```

Verify:

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=loki
kubectl -n monitoring get svc -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.clusterIPs}{"\n"}{end}'
```

## Tempo (Traces)

[Grafana Tempo](https://grafana.com/oss/tempo/) is a distributed tracing backend. We use the monolithic `tempo` chart from the `grafana-community` registry with local filesystem storage.

> **Note on Helm registries:** The `tempo` chart in `grafana.github.io/helm-charts` is deprecated. Use `oci://ghcr.io/grafana-community/helm-charts/tempo` instead — it's the actively maintained version.

### IPv4 only

```bash
helm upgrade --install --wait --timeout 10m \
  --namespace monitoring \
  tempo oci://ghcr.io/grafana-community/helm-charts/tempo \
  -f tempo-values.yaml
```

### Dual-stack

```bash
helm upgrade --install --wait --timeout 10m \
  --namespace monitoring \
  tempo oci://ghcr.io/grafana-community/helm-charts/tempo \
  -f tempo-dual-values.yaml

# Tempo chart doesn't support ipFamilyPolicy natively — patch after install
kubectl -n monitoring patch svc tempo --type=merge \
  -p '{"spec":{"ipFamilyPolicy":"PreferDualStack","ipFamilies":["IPv4","IPv6"]}}'
```

Verify:

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=tempo
kubectl -n monitoring get svc -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.clusterIPs}{"\n"}{end}'
```

## Alloy (Log & Trace Collector)

[Grafana Alloy](https://grafana.com/docs/alloy/latest/) is the recommended collector for the Grafana stack (replaces Promtail). It collects pod logs and sends them to Loki, and receives OTLP traces and forwards them to Tempo.

```bash
helm upgrade --install --wait --timeout 10m \
  --namespace monitoring \
  --repo https://grafana.github.io/helm-charts \
  alloy alloy -f alloy-values.yaml

# Alloy chart doesn't support ipFamilyPolicy natively — patch after install
kubectl -n monitoring patch svc alloy --type=merge \
  -p '{"spec":{"ipFamilyPolicy":"PreferDualStack","ipFamilies":["IPv4","IPv6"]}}'
```

Verify:

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=alloy
kubectl -n monitoring get svc alloy
```

The Alloy service should expose three ports: `4317` (OTLP gRPC), `4318` (OTLP HTTP), and `12345` (metrics). The OTLP ports are configured via `extraPorts` in the values file — without them, instrumented applications in other namespaces can't send traces to `alloy.monitoring:4317`.

## NGINX Gateway Fabric metrics

[NGINX Gateway Fabric](../nginx-fabric/) exposes Prometheus metrics on port 9113 from both components ([docs](https://docs.nginx.com/nginx-gateway-fabric/monitoring/prometheus/)):
- **Control plane** (`ngf-nginx-gateway-fabric`): controller-runtime metrics + NGF-specific metrics (e.g., `nginx_gateway_fabric_event_batch_processing_milliseconds`)
- **Data plane** (`nginx-shared-gateway-nginx`): NGINX metrics (e.g., `nginx_http_connection_count_connections`, `nginx_http_requests_total`)

Since kube-prometheus-stack uses the Prometheus Operator (ServiceMonitor/PodMonitor CRDs) rather than annotation-based discovery, we need PodMonitors to scrape both components.

> **Why PodMonitors?** The NGF helm chart doesn't create Services that expose the metrics port (9113). The metrics are only available on the pods directly.

```bash
kubectl apply -f nginx-gateway-fabric-podmonitor.yaml
```

> **Note:** The PodMonitor selector uses `app.kubernetes.io/instance: ngf` which is the helm release name and matches both control plane and data plane pods. If you installed NGF with a different release name, update the selector accordingly.

Verify Prometheus is scraping both:

```bash
kubectl -n monitoring get podmonitor nginx-gateway-fabric
```

> **Note:** The `PodMonitor` label `release: prometheus-stack` must match the Prometheus Operator's `podMonitorSelector`. The kube-prometheus-stack helm release name `prometheus-stack` (used in the install commands above) sets this automatically. If you used a different release name, update the label accordingly.

Then you can download and [import](https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/import-dashboards/) the [dashboard](https://docs.nginx.com/ngf/grafana-dashboard.json) shared in same [doc](https://docs.nginx.com/nginx-gateway-fabric/monitoring/prometheus/)

## Verify the Full Stack

### Check all pods

```bash
kubectl -n monitoring get pods
```

You should see pods for: prometheus, grafana, alertmanager, loki, tempo, alloy, node-exporter, kube-state-metrics.

### Get Grafana admin password

```bash
kubectl -n monitoring get secrets prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

### Get URLs

#### IPv4

```bash
kubectl -n monitoring get httproute
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
echo "Prometheus  - http://prometheus.$MY_PRIVATE_IP.nip.io:80/"
echo "Alertmanager - http://alertmanager.$MY_PRIVATE_IP.nip.io:80/"
echo "Grafana     - http://grafana.$MY_PRIVATE_IP.nip.io:80/"
```

#### IPv6 (dual-stack only)

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_GLOBAL_IP6="$(ip -6 addr show $iface scope global | grep -oP '(?<=inet6\s)[0-9a-f:]+(?=/)' | head -1 | tr ':' '-')"
echo "Prometheus  - http://prometheus.$MY_GLOBAL_IP6.nip.io:8080/"
echo "Alertmanager - http://alertmanager.$MY_GLOBAL_IP6.nip.io:8080/"
echo "Grafana     - http://grafana.$MY_GLOBAL_IP6.nip.io:8080/"
```

> **Note on IPv6 browser access:** Because kind requires different host ports for IPv6 (8080/8443 instead of 80/443), some applications (Prometheus, Alertmanager) that use HTTP redirects may not work correctly in browsers — the redirect drops the non-standard port. Use `curl -L` for testing, or access via IPv4 (port 80) for browser use. Grafana typically works fine since it doesn't redirect on the root path.

Open Grafana in your browser and verify:
1. **Prometheus datasource** — go to Connections → Data sources → Prometheus → Test
2. **Loki datasource** — go to Connections → Data sources → Loki → Test
3. **Tempo datasource** — go to Connections → Data sources → Tempo → Test

### Test Loki (logs)

In Grafana, go to Explore → select Loki datasource → run (Code):

```
{job="loki.source.kubernetes.pods"} |= ``
```

You should see all logs from your pods.

### Test Tempo (traces)

Tempo won't have traces until an application sends them via OTLP. You can verify the datasource is connected in Grafana → Explore → Tempo → Search.

To generate test traces, deploy an instrumented application or use the OTLP test:

```bash
# Send a test trace to Tempo's OTLP HTTP endpoint with dynamic timestamps
# Ref: https://grafana.com/docs/tempo/latest/api_docs/pushing-spans-with-http/
kubectl -n monitoring run otel-test --image=curlimages/curl --rm -it --restart=Never -- \
  sh -c 'END=$(date +%s)000000000; START=$(( $(date +%s) - 1 ))000000000; \
  curl -X POST -H "Content-Type: application/json" \
  http://tempo.monitoring:4318/v1/traces -d \
  "{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"my.service\"}}]},\"scopeSpans\":[{\"scope\":{\"name\":\"my.library\",\"version\":\"1.0.0\",\"attributes\":[{\"key\":\"my.scope.attribute\",\"value\":{\"stringValue\":\"some scope attribute\"}}]},\"spans\":[{\"traceId\":\"5B8EFFF798038103D269B633813FC700\",\"spanId\":\"EEE19B7EC3C1B100\",\"name\":\"I am a span!\",\"startTimeUnixNano\":$START,\"endTimeUnixNano\":$END,\"kind\":2,\"attributes\":[{\"key\":\"my.span.attr\",\"value\":{\"stringValue\":\"some value\"}}]}]}]}]}"'
```

> The `curlimages/curl` image (Alpine/BusyBox) doesn't support `date +%s%N`, so we use `date +%s` (epoch seconds) and append `000000000` to build nanosecond timestamps. The span gets a 1-second duration with timestamps from the moment the command runs.

## Trace Demo Application

To test distributed tracing with a real multi-tier application (Frontend → Backend → Redis) instrumented with OpenTelemetry auto-instrumentation, see the [trace-demo app](../app-examples/trace-demo/).

## Clean up

```bash
kubectl -n monitoring delete podmonitor nginx-gateway-fabric
helm -n monitoring uninstall alloy
helm -n monitoring uninstall tempo
helm -n monitoring uninstall loki
helm -n monitoring uninstall prometheus-stack
kubectl delete namespace monitoring
```
