# -------------------------------------------------------------------
# NGINX Gateway Fabric Module
# Reusable module that deploys:
#   - Gateway API CRDs
#   - NGINX Gateway Fabric (Helm)
#   - Shared Gateway resource
#   - NginxProxy config (data plane pinning)
# -------------------------------------------------------------------

data "external" "host_ip" {
  count   = var.private_ip == "" ? 1 : 0
  program = ["bash", "${path.module}/detect-ip.sh"]
}

locals {
  private_ip = var.private_ip != "" ? var.private_ip : data.external.host_ip[0].result.ip
}

# Gateway API CRDs
data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v${var.gateway_api_version}/standard-install.yaml"
}

data "kubectl_file_documents" "gateway_api_crds" {
  content = data.http.gateway_api_crds.response_body
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each          = data.kubectl_file_documents.gateway_api_crds.manifests
  yaml_body         = each.value
  server_side_apply = true
  force_conflicts   = true
}

# Namespace
resource "kubernetes_namespace" "nginx_gateway" {
  metadata {
    name = "nginx-gateway"
  }
}

# Helm release
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
      value = var.service_type
    },
    {
      name  = "nginx.service.nodePorts[0].name"
      value = "http"
    },
    {
      name  = "nginx.service.nodePorts[0].port"
      value = tostring(var.http_node_port)
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
      value = tostring(var.https_node_port)
    },
    {
      name  = "nginx.service.nodePorts[1].listenerPort"
      value = "443"
    },
    {
      name  = "nginxGateway.nodeSelector.kubernetes\\.io/hostname"
      value = lookup(var.node_selector, "kubernetes.io/hostname", "")
    },
  ]

  depends_on = [
    kubernetes_namespace.nginx_gateway,
    kubectl_manifest.gateway_api_crds,
  ]
}

# Shared Gateway
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

# Pin data plane to control-plane node
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
            nodeSelector = var.node_selector
          }
        }
      }
    }
  })

  depends_on = [helm_release.nginx_gateway_fabric]
}
