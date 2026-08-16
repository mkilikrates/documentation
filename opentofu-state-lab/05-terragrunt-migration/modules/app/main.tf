# -------------------------------------------------------------------
# Reusable App Module
# Deploys a colored web application with:
#   - Namespace (own namespace per app with shared-gateway-access label)
#   - ConfigMap (HTML page)
#   - Deployment (nginx:alpine)
#   - Service (ClusterIP)
#   - HTTPRoute (attached to shared gateway)
# -------------------------------------------------------------------

locals {
  namespace  = var.namespace != "" ? var.namespace : var.app_name
  private_ip = var.private_ip != "" ? var.private_ip : data.external.host_ip[0].result.ip
}

data "external" "host_ip" {
  count   = var.private_ip == "" ? 1 : 0
  program = ["bash", "${path.module}/detect-ip.sh"]
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = local.namespace
    labels = {
      "shared-gateway-access" = "true"
    }
  }
}

resource "kubernetes_config_map" "html" {
  metadata {
    name      = "${var.app_name}-html"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    "default.conf" = <<-EOF
      server {
        listen 80;
        root /usr/share/nginx/html;
        location / {
          try_files $uri /index.html;
        }
      }
    EOF

    "index.html" = <<-EOF
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>${title(var.app_name)} App</title>
        <style>
          body {
            background-color: ${var.app_color};
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
          <h1>${var.app_emoji} ${title(var.app_name)} App</h1>
          <p>Managed by OpenTofu</p>
          <p><small>Namespace: ${local.namespace} | Host: ${var.app_name}.IP.nip.io</small></p>
        </div>
      </body>
      </html>
    EOF
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "${var.app_name}-app"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = var.app_name
    }
  }

  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = var.app_name
      }
    }
    template {
      metadata {
        labels = {
          app = var.app_name
        }
        annotations = {
          "configmap-hash" = sha256(jsonencode(kubernetes_config_map.html.data))
        }
      }
      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }
          volume_mount {
            name       = "nginx-conf"
            mount_path = "/etc/nginx/conf.d"
          }
          resources {
            requests = {
              cpu    = "50m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }
        }
        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.html.metadata[0].name
            items {
              key  = "index.html"
              path = "index.html"
            }
          }
        }
        volume {
          name = "nginx-conf"
          config_map {
            name = kubernetes_config_map.html.metadata[0].name
            items {
              key  = "default.conf"
              path = "default.conf"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "${var.app_name}-service"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      app = var.app_name
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

resource "kubectl_manifest" "httproute" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${var.app_name}-route"
      namespace = local.namespace
    }
    spec = {
      parentRefs = [
        {
          name      = var.gateway_name
          namespace = var.gateway_namespace
        }
      ]
      hostnames = ["${var.app_name}.${local.private_ip}.nip.io"]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = var.app_path
              }
            }
          ]
          backendRefs = [
            {
              name = "${var.app_name}-service"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [kubernetes_service.app]
}

# Path-based route: apps.<IP>.nip.io/<app_name>
resource "kubectl_manifest" "httproute_path" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${var.app_name}-route-path"
      namespace = local.namespace
    }
    spec = {
      parentRefs = [
        {
          name      = var.gateway_name
          namespace = var.gateway_namespace
        }
      ]
      hostnames = ["apps.${local.private_ip}.nip.io"]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/${var.app_name}"
              }
            }
          ]
          backendRefs = [
            {
              name = "${var.app_name}-service"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [kubernetes_service.app]
}
