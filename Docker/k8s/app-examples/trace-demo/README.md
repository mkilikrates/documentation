# Trace Demo — Multi-Tier App with OpenTelemetry

A simple three-tier application (Frontend → Backend → Redis) instrumented with OpenTelemetry auto-instrumentation for distributed tracing.

## Architecture

```
Browser → Gateway → Frontend (Flask) → Backend (Flask) → Redis
                        │                    │              │
                        └── OTLP traces ─────┴──── OTLP ───┘──► Alloy → Tempo
```

All three services send traces to Alloy via OTLP, which forwards them to Tempo. No custom Docker images needed — the app code is mounted via ConfigMaps and OTel packages are installed at startup via init containers.

## Prerequisites

- The observability stack from [monitoring](../../monitoring/) must be running
- [NGINX Gateway Fabric](../../nginx-fabric/) with a shared gateway

## Deploy

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < trace-demo.yaml | kubectl apply -f -
```

## Verify

```bash
kubectl -n trace-demo get pods -w
kubectl -n trace-demo logs -l app=frontend --tail=5
```

## Access

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
# Frontend
curl http://trace-demo.$MY_PRIVATE_IP.nip.io/
curl http://trace-demo.$MY_PRIVATE_IP.nip.io/items
curl http://trace-demo.$MY_PRIVATE_IP.nip.io/items -X POST -H "Content-Type: application/json" -d '{"name":"test-item","value":"42"}'
```

## View traces

In Grafana → Explore → Tempo → Search → Service Name: `frontend` or `backend`

## Clean up

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < trace-demo.yaml | kubectl delete -f -
```
