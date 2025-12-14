# Kubernetes Ingress and Gateway API Examples

This folder contains examples for both traditional Ingress and modern Gateway API (HTTPRoute) implementations. Both examples deploy 2 [pods](https://kubernetes.io/docs/concepts/workloads/pods/) and [services](https://kubernetes.io/docs/concepts/services-networking/service/) that can be accessed based on URI path (red or blue).

## Table of Contents

- [Traditional Ingress Example](#traditional-ingress-example)
- [Gateway API HTTPRoute Example](#gateway-api-httproute-example)
- [Comparison](#comparison)
- [Clean up](#clean-up)

## Traditional Ingress Example

### Prerequisites

- Kind cluster created with standard [cluster.yaml](../../kind/cluster.yaml)
- nginx ingress controller installed (see [Kind README](../../kind/README.md#nginx-ingress))

### agnhost Image

[Official documentation about this image](https://pkg.go.dev/k8s.io/kubernetes/test/images/agnhost#section-readme)

### Deploy with Ingress

Deploy 2 pods using the traditional Ingress approach with [red-blue-service.yaml file](red-blue-service.yaml):

```bash
kubectl apply -f red-blue-service.yaml
```

Check that it is running:

```bash
kubectl -n red-blue-ingress get all
```

Expected output:

```bash
NAME           READY   STATUS    RESTARTS   AGE
pod/blue-app   1/1     Running   0          80s
pod/red-app    1/1     Running   0          80s

NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/blue-service   ClusterIP   10.96.104.156   <none>        8080/TCP   80s
service/red-service    ClusterIP   10.96.66.147    <none>        8080/TCP   80s

NAME                                CLASS   HOSTS   ADDRESS   PORTS   AGE
ingress.networking.k8s.io/app-selector-ingress   <none>   *       localhost   80      80s
```

### Access Services (Ingress)

Access using your browser or curl on fixed ports:

- [app-red](http://127.0.0.1:80/red)
- [app-blue](http://127.0.0.1:80/blue)

```bash
curl http://127.0.0.1/red
curl http://127.0.0.1/blue
```

## Gateway API HTTPRoute Example

### Prerequisites

- Kind cluster created with [cluster-gateway.yaml](../../kind/cluster-gateway.yaml)
- Gateway API CRDs and Envoy Gateway installed
- cloud-provider-kind running with LoadBalancer port mapping
- See complete setup in [Kind README](../../kind/README.md#gateway-api-with-envoy-gateway)

### Deploy with HTTPRoute

Deploy 2 pods using the modern Gateway API approach with [red-blue-httproute.yaml file](red-blue-httproute.yaml):

```bash
kubectl apply -f red-blue-httproute.yaml
```

Check that it is running:

```bash
kubectl -n red-blue-httproute get all
```

Expected output:

```bash
NAME           READY   STATUS    RESTARTS   AGE
pod/blue-app   1/1     Running   0          2m
pod/red-app    1/1     Running   0          2m

NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/blue-service   ClusterIP   10.96.27.156   <none>        8080/TCP   2m
service/red-service    ClusterIP   10.96.66.147   <none>        8080/TCP   2m
```

Check Gateway and HTTPRoute status:

```bash
kubectl get gateway -n red-blue-httproute
kubectl get httproute -n red-blue-httproute
kubectl get svc -n envoy-gateway-system
```

### Access Services (HTTPRoute)

Find the dynamically assigned ports:

```bash
docker ps | grep kindccm
```

Example output:
```bash
db3269d0f2ee   envoyproxy/envoy:v1.30.1   ...   0.0.0.0:51680->80/tcp, 0.0.0.0:52714->10000/tcp   kindccm-...
```

Access using the dynamically assigned HTTP port (51680 in this example):

- app-red: `http://localhost:51680/red`
- app-blue: `http://localhost:51680/blue`

```bash
curl http://localhost:51680/red
curl http://localhost:51680/blue
```

Admin interface available at: `http://localhost:52714/`

## Comparison

| Feature | Traditional Ingress | Gateway API HTTPRoute |
|---------|-------------------|----------------------|
| **API Version** | networking.k8s.io/v1 | gateway.networking.k8s.io/v1 |
| **Resource Type** | Ingress | Gateway + HTTPRoute |
| **Port Access** | Fixed (80/443) | Dynamic LoadBalancer ports |
| **Setup Complexity** | Simple | Moderate (requires Gateway controller) |
| **Advanced Routing** | Limited | Extensive (headers, weights, filters) |
| **Multi-protocol** | HTTP/HTTPS only | HTTP, HTTPS, TCP, UDP, gRPC |
| **Traffic Splitting** | Limited | Native support |
| **Extensibility** | Limited | Highly extensible |
| **Maturity** | Stable, widely adopted | Newer, evolving standard |
| **Use Case** | Simple HTTP routing | Advanced traffic management |

### When to Use Each

**Use Traditional Ingress when:**
- Simple HTTP/HTTPS routing needs
- Fixed port requirements (80/443)
- Existing nginx ingress infrastructure
- Straightforward path-based routing

**Use Gateway API HTTPRoute when:**
- Advanced routing requirements
- Need for traffic splitting or canary deployments
- Multi-protocol support needed
- Future-proofing with modern Kubernetes networking
- Complex traffic policies and filters

## Clean up

### Clean up Ingress Example

```bash
kubectl delete -f red-blue-service.yaml
```

### Clean up HTTPRoute Example

```bash
kubectl delete -f red-blue-httproute.yaml
```

### Clean up Gateway Infrastructure

If you want to remove the entire Gateway API setup:

```bash
# Stop cloud-provider-kind
docker stop cloud-provider-kind

# Remove Gateway Class
kubectl delete gatewayclass eg

# Remove Envoy Gateway (optional)
kubectl delete -f https://github.com/envoyproxy/gateway/releases/download/v1.6.1/install.yaml

# Remove Gateway API CRDs (optional)
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

### Complete Cluster Cleanup

To remove the entire kind cluster:

```bash
kind delete cluster
```
