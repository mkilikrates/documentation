# -------------------------------------------------------------------
# Green Application
# Copy this file to ../02-deploy/apps/ when performing the import exercise.
# After copying, use 'tofu import' CLI commands to bring existing
# resources under management (see Phase 4 README for commands).
# -------------------------------------------------------------------

# Resources

resource "kubernetes_namespace" "green" {
  metadata {
    name = "green"
    labels = {
      "shared-gateway-access" = "true"
    }
  }
}

resource "kubernetes_config_map" "green_html" {
  metadata {
    name      = "green-html"
    namespace = kubernetes_namespace.green.metadata[0].name
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
    EOF
  }
}

resource "kubernetes_deployment" "green" {
  metadata {
    name      = "green-app"
    namespace = kubernetes_namespace.green.metadata[0].name
    labels = {
      app = "green"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "green"
      }
    }
    template {
      metadata {
        labels = {
          app = "green"
        }
        annotations = {
          "configmap-hash" = sha256(jsonencode(kubernetes_config_map.green_html.data))
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
            name = kubernetes_config_map.green_html.metadata[0].name
            items {
              key  = "index.html"
              path = "index.html"
            }
          }
        }
        volume {
          name = "nginx-conf"
          config_map {
            name = kubernetes_config_map.green_html.metadata[0].name
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

resource "kubernetes_service" "green" {
  metadata {
    name      = "green-service"
    namespace = kubernetes_namespace.green.metadata[0].name
  }

  spec {
    selector = {
      app = "green"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

resource "kubectl_manifest" "green_httproute" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "green-route"
      namespace = "green"
    }
    spec = {
      parentRefs = [
        {
          name      = "nginx-shared-gateway"
          namespace = "nginx-gateway"
        }
      ]
      hostnames = ["green.${local.private_ip}.nip.io"]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = "green-service"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [
    kubernetes_namespace.green,
    kubernetes_service.green,
  ]
}

# Path-based route: apps.<IP>.nip.io/green
resource "kubectl_manifest" "green_httproute_path" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "green-route-path"
      namespace = "green"
    }
    spec = {
      parentRefs = [
        {
          name      = "nginx-shared-gateway"
          namespace = "nginx-gateway"
        }
      ]
      hostnames = ["apps.${local.private_ip}.nip.io"]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/green"
              }
            }
          ]
          backendRefs = [
            {
              name = "green-service"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [
    kubernetes_namespace.green,
    kubernetes_service.green,
  ]
}
