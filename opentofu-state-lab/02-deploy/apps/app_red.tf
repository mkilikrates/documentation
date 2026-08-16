# -------------------------------------------------------------------
# Red Application
# A simple nginx pod serving a red-themed HTML page
# Each app gets its own namespace with shared-gateway-access label
# -------------------------------------------------------------------

resource "kubernetes_namespace" "red" {
  metadata {
    name = "red"
    labels = {
      "shared-gateway-access" = "true"
    }
  }
}

resource "kubernetes_config_map" "red_html" {
  metadata {
    name      = "red-html"
    namespace = kubernetes_namespace.red.metadata[0].name
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
        <title>Red App</title>
        <style>
          body {
            background-color: #dc3545;
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
          <h1>🔴 Red App</h1>
          <p>Managed by OpenTofu</p>
          <p><small>Namespace: red | Host: red.IP.nip.io</small></p>
        </div>
      </body>
      </html>
    EOF
  }
}

resource "kubernetes_deployment" "red" {
  metadata {
    name      = "red-app"
    namespace = kubernetes_namespace.red.metadata[0].name
    labels = {
      app = "red"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "red"
      }
    }
    template {
      metadata {
        labels = {
          app = "red"
        }
        annotations = {
          # Force rolling update when ConfigMap content changes
          "configmap-hash" = sha256(jsonencode(kubernetes_config_map.red_html.data))
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
            name = kubernetes_config_map.red_html.metadata[0].name
            items {
              key  = "index.html"
              path = "index.html"
            }
          }
        }
        volume {
          name = "nginx-conf"
          config_map {
            name = kubernetes_config_map.red_html.metadata[0].name
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

resource "kubernetes_service" "red" {
  metadata {
    name      = "red-service"
    namespace = kubernetes_namespace.red.metadata[0].name
  }

  spec {
    selector = {
      app = "red"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

# Host-based route: red.<IP>.nip.io
resource "kubectl_manifest" "red_httproute" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "red-route"
      namespace = "red"
    }
    spec = {
      parentRefs = [
        {
          name      = "nginx-shared-gateway"
          namespace = "nginx-gateway"
        }
      ]
      hostnames = ["red.${local.private_ip}.nip.io"]
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
              name = "red-service"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [
    kubernetes_namespace.red,
    kubernetes_service.red,
  ]
}

# Path-based route: apps.<IP>.nip.io/red
resource "kubectl_manifest" "red_httproute_path" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "red-route-path"
      namespace = "red"
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
                value = "/red"
              }
            }
          ]
          backendRefs = [
            {
              name = "red-service"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [
    kubernetes_namespace.red,
    kubernetes_service.red,
  ]
}
