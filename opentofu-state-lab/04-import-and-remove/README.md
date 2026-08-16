# Phase 4 — Import and Remove

This phase covers two common scenarios:
1. A resource was **deleted** outside OpenTofu — you need to clean up state
2. A resource was **created** outside OpenTofu — you need to bring it under management

## Exercise 1 — Remove from State (Resource Deleted Externally)

Someone deleted the blue app's entire namespace directly:

```bash
kubectl delete namespace blue
```

Now check what OpenTofu thinks:

```bash
cd ../02-deploy/apps
tofu plan
```

**What you'll see:** OpenTofu wants to recreate the blue namespace and all resources in it — because they exist in state but not in the cluster.

### Option A — Remove from state (declarative `removed` block)

If you don't want to recreate the blue app, edit `app_blue.tf` and replace all resource blocks with:

```hcl
removed {
  from = kubernetes_namespace.blue
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_config_map.blue_html
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_deployment.blue
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_service.blue
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubectl_manifest.blue_httproute
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubectl_manifest.blue_httproute_path
  lifecycle {
    destroy = false
  }
}
```

Then apply:

```bash
tofu apply
```

OpenTofu removes the resources from state without trying to delete them (they're already gone). After apply, you can delete the `removed` blocks or the entire `app_blue.tf` file.

### Option B — Remove from state (CLI)

Alternatively, use the CLI to remove each resource from state:

```bash
tofu state rm kubernetes_namespace.blue
tofu state rm kubernetes_config_map.blue_html
tofu state rm kubernetes_deployment.blue
tofu state rm kubernetes_service.blue
tofu state rm kubectl_manifest.blue_httproute
tofu state rm kubectl_manifest.blue_httproute_path
```

Then remove the resource blocks from `app_blue.tf` (or delete the file).

> **When to use which:** The `removed` block is safer for teams — it's declarative, reviewable in PRs, and won't accidentally recreate deleted resources. The CLI is faster for one-off fixes.

---

## Exercise 2 — Import (Resource Created Externally)

Someone deployed a green app manually with its own namespace:

```bash
# Ensure your IP is set (same as Phase 1)
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
```

### Step 1 — Write the matching OpenTofu config

Copy `app_green.tf` to `../02-deploy/apps/`:

```bash
cp app_green.tf ../02-deploy/apps/
```

### Step 2 — Import resources via CLI

From the apps folder, import each existing resource into state:

```bash
cd ../02-deploy/apps

# Import namespace
tofu import 'kubernetes_namespace.green' 'green'

# Import configmap
tofu import 'kubernetes_config_map.green_html' 'green/green-html'

# Import deployment
tofu import 'kubernetes_deployment.green' 'green/green-app'

# Import service
tofu import 'kubernetes_service.green' 'green/green-service'

# Import HTTPRoutes
tofu import 'kubectl_manifest.green_httproute' "gateway.networking.k8s.io/v1//HTTPRoute//green-route//green"
tofu import 'kubectl_manifest.green_httproute_path' "gateway.networking.k8s.io/v1//HTTPRoute//green-route-path//green"
```

### Step 3 — Plan and verify

```bash
tofu plan
```

**What you expect:** The plan should show minimal or no changes. Some computed defaults may differ (e.g., `wait_for_rollout`, `automount_service_account_token`) — these are OpenTofu defaults that don't affect the running infrastructure. The `configmap-hash` annotation will trigger a one-time rolling update.

### Step 4 — Apply to reconcile

```bash
tofu apply
```

This applies any minor drift between the kubectl-created resources and what OpenTofu expects.

### Step 5 — Verify everything is clean

```bash
tofu plan
```

The plan should show "No changes" — everything is now under OpenTofu management.

### Test the green app

```bash
export iface=$(route | grep '^default' | grep -o '[^ ]*$')
export MY_PRIVATE_IP="$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"

# Host-based
curl http://green.$MY_PRIVATE_IP.nip.io

# Path-based
curl http://apps.$MY_PRIVATE_IP.nip.io/green
```

Or open either URL in your browser.

---

## Key Takeaways

| Scenario | Tool | When to Use |
|----------|------|-------------|
| Resource deleted externally | `removed` block | Team workflows, PR-reviewable |
| Resource deleted externally | `tofu state rm` | Quick one-off fixes |
| Resource created externally | `import` block | Declarative, repeatable |
| Resource created externally | `tofu import` CLI | Quick imports, `kubectl_manifest` types |

## Next Step

Proceed to [05-terragrunt-migration](../05-terragrunt-migration/) to migrate from a monolithic state to a split Terragrunt structure.
