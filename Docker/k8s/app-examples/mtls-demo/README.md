# mTLS Demo — SPIFFE/SPIRE Workload Identity

A two-tier application (Frontend → Backend) demonstrating mutual TLS with SPIFFE workload identity. The frontend is exposed via plaintext HTTP (Gateway API), but communicates with the backend over mTLS using automatically issued SPIFFE SVIDs.

## Architecture

```
Browser → Gateway → Frontend (Flask, HTTP:8080) ──mTLS──► Backend (Flask, HTTPS:8443)
                         │                                       │
                         │  spiffe-helper sidecar                │  spiffe-helper sidecar
                         │  fetches certs from SPIRE             │  fetches certs from SPIRE
                         └───────────────────────────────────────┘
                                         │
                              SPIRE Agent (Workload API)
```

- **Frontend**: Accepts plaintext HTTP requests from users, or https offload by Gateway API, calls the backend over mTLS using its SPIFFE identity. Validates the backend's SPIFFE ID.
- **Backend**: Only accepts mTLS connections. Verifies the client's SPIFFE ID belongs to the allowed list.
- **Attacker**: A pod in the same namespace without SPIRE certs — proves that network proximity alone is not enough.

No custom Docker images needed — app code is mounted via ConfigMaps and dependencies are installed at startup via init containers.

**Note**: 

**Frontend Routes**:
- '/' - frontend status (static reply)
- '/data' - get data from backend
- '/whoami' - get both frontend and backend spiffe_ids

## Prerequisites

- SPIRE installed with the SPIFFE CSI driver (see the [security series article](../../../../articles/k8s-security-series/part1-mtls-workload-identity.md))
- [NGINX Gateway Fabric](../../nginx-fabric/) with a shared gateway (optional, for external access)

## Deploy

```bash
# ipv4 only
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < mtls-demo.yaml | kubectl apply -f -
# dual-stack
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
export MY_GLOBAL_IP6="$(ip -6 addr show $iface scope global | grep -oP '(?<=inet6\s)[0-9a-f:]+(?=/)'| head -1 | tr ':' '-')"
envsubst < mtls-demo-dual.yaml | kubectl apply -f -
```

## Verify

```bash
kubectl -n mtls-demo get pods -w
kubectl -n mtls-demo logs -l app=frontend -c frontend --tail=5
# get pod ips
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}} : {{range .status.podIPs}}{{printf "%s " .ip}}{{end}}{{"\n"}}{{end}}' -n mtls-demo
```

## Test

### mTLS working (frontend → backend)

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"

# Via Gateway — HTTP
curl http://mtls-demo.$MY_PRIVATE_IP.nip.io/
curl http://mtls-demo.$MY_PRIVATE_IP.nip.io/data
curl http://mtls-demo.$MY_PRIVATE_IP.nip.io/whoami
# Via Gateway — HTTPS (self-signed cert, use -k)
curl -k https://mtls-demo.$MY_PRIVATE_IP.nip.io/
curl -k https://mtls-demo.$MY_PRIVATE_IP.nip.io/data
curl -k https://mtls-demo.$MY_PRIVATE_IP.nip.io/whoami
# Via ipv6 (to frontend from attacker = open)
kubectl -n mtls-demo exec deploy/attacker -- \
  nslookup -type=a frontend.mtls-demo.svc.cluster.local
kubectl -n mtls-demo exec deploy/attacker -- \
  nslookup -type=aaaa frontend.mtls-demo.svc.cluster.local
kubectl -n mtls-demo exec deploy/attacker -- \
  curl -4 -s http://frontend.mtls-demo.svc.cluster.local:8080
kubectl -n mtls-demo exec deploy/attacker -- \
  curl -6 -s http://frontend.mtls-demo.svc.cluster.local:8080
# verbose
kubectl -n mtls-demo exec deploy/attacker -- \
  curl -6 -iv http://frontend.mtls-demo.svc.cluster.local:8080
```

### mTLS rejected (attacker pod without certs)

```bash
# The attacker pod tries to reach the backend directly — fails
kubectl -n mtls-demo exec deploy/attacker -- \
  curl -s -k https://backend.mtls-demo.svc.cluster.local:8443/data

# Also fails with plaintext
kubectl -n mtls-demo exec deploy/attacker -- \
  curl -s http://backend.mtls-demo.svc.cluster.local:8443/data

# Getting details with verbose output
kubectl -n mtls-demo exec deploy/attacker -- \
  curl -ivk https://backend.mtls-demo.svc.cluster.local:8443/data
```

The verbose output tells the full story of why the attacker is rejected:

```
* TLSv1.3 (OUT), TLS handshake, Client hello (1):        ← Attacker initiates TLS
* TLSv1.3 (IN), TLS handshake, Server hello (2):         ← Backend responds
* TLSv1.3 (IN), TLS handshake, Request CERT (13):        ← Backend DEMANDS a client certificate
* TLSv1.3 (IN), TLS handshake, Certificate (11):         ← Backend presents its SVID
* TLSv1.3 (OUT), TLS handshake, Certificate (11):        ← Attacker sends EMPTY certificate (has none)
* Server certificate:
*   subject: C=US; O=SPIRE                               ← Backend's cert was issued by SPIRE
*   issuer: C=IE; O=KilikratesLab; CN=SPIRE CA           ← Signed by our SPIRE CA chain
* Send failure: Connection reset by peer                  ← Backend REJECTS — no valid client cert
curl: (55) Send failure: Connection reset by peer
```

Here's what happened step by step:

1. **Client Hello** — The attacker starts a TLS handshake like any normal client
2. **Request CERT** — The backend's `ssl.CERT_REQUIRED` setting tells the client: "I need your certificate to proceed"
3. **Empty Certificate** — The attacker has no SPIFFE identity, no CSI volume, no certs — it sends an empty certificate message
4. **Connection Reset** — The backend's Python `ssl` module verifies the client cert against the SPIRE trust bundle (`svid_bundle.pem`). An empty cert fails verification → connection is terminated immediately

The attacker can resolve the DNS name, reach the port, and even complete part of the TLS handshake — but without a valid SVID signed by the SPIRE CA, the connection is killed before any HTTP data is exchanged. **Network access alone is not enough.**

## Clean up

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
envsubst < mtls-demo.yaml | kubectl delete -f -
```
