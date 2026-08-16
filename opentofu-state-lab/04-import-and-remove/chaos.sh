#!/bin/bash
# -------------------------------------------------------------------
# Chaos Script — Phase 4: Import and Remove
# Run these commands to set up the import/remove exercises.
# -------------------------------------------------------------------

set -e

echo "=== Exercise 1: Delete blue app externally ==="
echo "Deleting the entire blue namespace (and all resources in it)..."
kubectl delete namespace blue --ignore-not-found

echo ""
echo "=== Exercise 2: Create green app externally ==="
echo "Deploying green app with kubectl..."

# Get private IP for nip.io hostname
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: green
  labels:
    shared-gateway-access: "true"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: green-html
  namespace: green
data:
  default.conf: |
    server {
      listen 80;
      root /usr/share/nginx/html;
      location / {
        try_files \$uri /index.html;
      }
    }
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>Green App</title>
      <style>
        body {
          background-color: #198754;
          color: white;
          font-family: 'Segoe UI', Arial, sans-serif;
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          margin: 0;
        }
        .container {
          text-align: center;
          padding: 2rem;
          background: rgba(0,0,0,0.2);
          border-radius: 16px;
        }
        h1 { font-size: 3rem; margin-bottom: 0.5rem; }
        p { font-size: 1.2rem; opacity: 0.9; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🟢 Green App</h1>
        <p>Managed by OpenTofu</p>
        <p><small>Namespace: green | Host: green.IP.nip.io</small></p>
      </div>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: green-app
  namespace: green
  labels:
    app: green
spec:
  replicas: 2
  selector:
    matchLabels:
      app: green
  template:
    metadata:
      labels:
        app: green
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: nginx-conf
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
          limits:
            cpu: 100m
            memory: 64Mi
      volumes:
      - name: html
        configMap:
          name: green-html
          items:
          - key: index.html
            path: index.html
      - name: nginx-conf
        configMap:
          name: green-html
          items:
          - key: default.conf
            path: default.conf
---
apiVersion: v1
kind: Service
metadata:
  name: green-service
  namespace: green
spec:
  selector:
    app: green
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: green-route
  namespace: green
spec:
  parentRefs:
  - name: nginx-shared-gateway
    namespace: nginx-gateway
  hostnames:
  - "green.${MY_PRIVATE_IP}.nip.io"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: green-service
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: green-route-path
  namespace: green
spec:
  parentRefs:
  - name: nginx-shared-gateway
    namespace: nginx-gateway
  hostnames:
  - "apps.${MY_PRIVATE_IP}.nip.io"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /green
    backendRefs:
    - name: green-service
      port: 80
EOF

echo ""
echo "=== Chaos complete ==="
echo ""
echo "Blue namespace has been deleted externally."
echo "Green namespace + app has been created externally."
echo ""
echo "Next steps:"
echo "  1. cd ../02-deploy/apps && tofu plan  (see what OpenTofu wants to do)"
echo "  2. Follow the README for remove and import exercises"
