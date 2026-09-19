# NGINX Gateway Fabric — Expose services externally via Gateway API
# Same pattern as the Networking, Observability, and Security series.

resource "null_resource" "gateway_api_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      export gatewayapiversion=$(curl -Ls -o /dev/null -w '%%{url_effective}' \
        https://github.com/nginx/nginx-gateway-fabric/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
      kubectl kustomize \
        "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v$${gatewayapiversion}" \
        | kubectl apply -f -
    EOT
  }
}

resource "helm_release" "nginx_gateway_fabric" {
  name             = "ngf"
  repository       = "oci://ghcr.io/nginx/charts"
  chart            = "nginx-gateway-fabric"
  namespace        = "nginx-gateway"
  create_namespace = true

  wait    = true
  timeout = 300

  set {
    name  = "nginx.service.type"
    value = "NodePort"
  }

  set {
    name  = "nginx.service.nodePorts[0].name"
    value = "http"
  }
  set {
    name  = "nginx.service.nodePorts[0].port"
    value = "31437"
  }
  set {
    name  = "nginx.service.nodePorts[0].listenerPort"
    value = "80"
  }

  set {
    name  = "nginx.service.nodePorts[1].name"
    value = "https"
  }
  set {
    name  = "nginx.service.nodePorts[1].port"
    value = "31438"
  }
  set {
    name  = "nginx.service.nodePorts[1].listenerPort"
    value = "443"
  }

  set {
    name  = "nginxGateway.nodeSelector.kubernetes\\.io/hostname"
    value = var.control_plane_node
  }

  depends_on = [null_resource.gateway_api_crds]
}

# Pin data plane to control-plane node (Kind-specific)
resource "null_resource" "pin_dataplane" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --timeout=5m -n nginx-gateway deployment/ngf-nginx-gateway-fabric --for=condition=Available
      kubectl -n nginx-gateway patch nginxproxy ngf-proxy-config --type=merge \
        -p '{"spec":{"kubernetes":{"deployment":{"pod":{"nodeSelector":{"kubernetes.io/hostname":"${var.control_plane_node}"}}}}}}'
    EOT
  }

  depends_on = [helm_release.nginx_gateway_fabric]
}

# Shared Gateway with HTTP listener
resource "null_resource" "shared_gateway" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<EOF
      apiVersion: gateway.networking.k8s.io/v1
      kind: Gateway
      metadata:
        name: shared-gateway
        namespace: nginx-gateway
      spec:
        gatewayClassName: nginx
        listeners:
        - name: http
          hostname: "*.${var.domain}"
          protocol: HTTP
          port: 80
          allowedRoutes:
            namespaces:
              from: All
      EOF
    EOT
  }

  depends_on = [null_resource.pin_dataplane]
}
