# -------------------------------------------------------------------
# Infrastructure: Gateway API CRDs + NGINX Gateway Fabric + Shared Gateway
#
# This must be applied BEFORE the apps/ folder, because the apps
# need the Gateway API CRDs and the shared gateway to exist.
# This mirrors real-world practice: platform team deploys infra,
# app teams deploy their services on top.
# -------------------------------------------------------------------

# Install Gateway API CRDs using kubectl_manifest from the official kustomize output
# We use the kubectl provider because it doesn't require CRDs to exist at plan time
resource "kubectl_manifest" "gateway_api_crds" {
  for_each = data.kubectl_file_documents.gateway_api_crds.manifests

  yaml_body = each.value

  server_side_apply = true
  force_conflicts   = true
}

data "kubectl_file_documents" "gateway_api_crds" {
  content = data.http.gateway_api_crds.response_body
}

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v${var.gateway_api_version}/standard-install.yaml"
}

# NGINX Gateway Fabric namespace
resource "kubernetes_namespace" "nginx_gateway" {
  metadata {
    name = "nginx-gateway"
  }
}

# Install NGINX Gateway Fabric via Helm
# Pinned to v2.6.6 — we'll manually upgrade to v2.6.7 in Phase 3 to create drift
resource "helm_release" "nginx_gateway_fabric" {
  name             = "ngf"
  namespace        = kubernetes_namespace.nginx_gateway.metadata[0].name
  repository       = "oci://ghcr.io/nginx/charts"
  chart            = "nginx-gateway-fabric"
  version          = var.nginx_fabric_version
  create_namespace = false

  set = [
    {
      name  = "nginx.service.type"
      value = "NodePort"
    },
    {
      name  = "nginx.service.nodePorts[0].name"
      value = "http"
    },
    {
      name  = "nginx.service.nodePorts[0].port"
      value = "31437"
    },
    {
      name  = "nginx.service.nodePorts[0].listenerPort"
      value = "80"
    },
    {
      name  = "nginx.service.nodePorts[1].name"
      value = "https"
    },
    {
      name  = "nginx.service.nodePorts[1].port"
      value = "31438"
    },
    {
      name  = "nginx.service.nodePorts[1].listenerPort"
      value = "443"
    },
    {
      name  = "nginxGateway.nodeSelector.kubernetes\\.io/hostname"
      value = "kind-control-plane"
    },
  ]

  depends_on = [
    kubernetes_namespace.nginx_gateway,
    kubectl_manifest.gateway_api_crds,
  ]
}

# Shared Gateway resource
# Allows multiple apps to attach HTTPRoutes from namespaces with the label
resource "kubectl_manifest" "shared_gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "nginx-shared-gateway"
      namespace = "nginx-gateway"
    }
    spec = {
      gatewayClassName = "nginx"
      listeners = [
        {
          name     = "http"
          hostname = "*.${local.private_ip}.nip.io"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "shared-gateway-access" = "true"
                }
              }
            }
          }
        }
      ]
    }
  })

  depends_on = [helm_release.nginx_gateway_fabric]
}

# Pin the data plane pods to the control-plane node
# Kind only maps ports on the control-plane, so nginx data plane must run there
resource "kubectl_manifest" "nginx_proxy_config" {
  yaml_body = yamlencode({
    apiVersion = "gateway.nginx.org/v1alpha2"
    kind       = "NginxProxy"
    metadata = {
      name      = "ngf-proxy-config"
      namespace = "nginx-gateway"
    }
    spec = {
      kubernetes = {
        deployment = {
          pod = {
            nodeSelector = {
              "kubernetes.io/hostname" = "kind-control-plane"
            }
          }
        }
      }
    }
  })

  depends_on = [helm_release.nginx_gateway_fabric]
}
