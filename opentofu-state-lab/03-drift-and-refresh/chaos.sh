#!/bin/bash
# -------------------------------------------------------------------
# Chaos Script — Phase 3: Drift and Refresh
# Run these commands to introduce drift into your environment.
# Then use 'tofu plan' from 02-deploy/ to detect the drift.
# -------------------------------------------------------------------

set -e

echo "=== Exercise 1: Helm Upgrade Drift ==="
echo "Upgrading NGINX Gateway Fabric from 2.6.6 to 2.6.7..."
helm upgrade ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  -n nginx-gateway \
  --version 2.6.7 \
  --set nginx.service.type=NodePort \
  --set-json 'nginx.service.nodePorts=[{"name":"http","port":31437,"listenerPort":80},{"name":"https","port":31438,"listenerPort":443}]' \
  --set-json 'nginxGateway.nodeSelector={"kubernetes.io/hostname":"kind-control-plane"}'

echo ""
echo "=== Exercise 2: Replica Scaling Drift ==="
echo "Scaling red-app to 5 replicas..."
kubectl -n red scale deployment red-app --replicas=5

echo ""
echo "=== Exercise 3: ConfigMap Drift ==="
echo "Modifying blue app HTML content..."
kubectl -n blue patch configmap blue-html --type=merge \
  -p '{"data":{"index.html":"<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><title>Blue App</title><style>body{background-color:#0d6efd;color:white;font-family:Arial,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0}.container{text-align:center;padding:2rem;background:rgba(0,0,0,0.2);border-radius:16px}h1{font-size:3rem;margin-bottom:0.5rem}p{font-size:1.2rem;opacity:0.9}</style></head><body><div class=\"container\"><h1>🔵 Blue App (HOTFIX)</h1><p>Modified outside OpenTofu!</p><p><small>Namespace: blue | Host: blue.IP.nip.io</small></p></div></body></html>"}}'

echo ""
echo "=== All drift introduced ==="
echo "Now run:"
echo "  Helm drift:    cd ../02-deploy/infra && tofu plan"
echo "  App drift:     cd ../02-deploy/apps && tofu plan"
echo "You should see changes detected in both."
