terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "namespace" {
  type = string
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-kind"
  #   host = var.host

  #   client_certificate     = base64decode(var.client_certificate)
  #   client_key             = base64decode(var.client_key)
  #   cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

resource "kubernetes_namespace" "scalable_nginx" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "scalable-nginx"
    namespace = kubernetes_namespace.scalable_nginx.metadata[0].name
    labels = {
      App = "ScalableNginx"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "ScalableNginx"
      }
    }
    template {
      metadata {
        labels = {
          App = "ScalableNginx"
        }
      }
      spec {
        container {
          image = "nginx"
          name  = "web-server"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx_service" {
  metadata {
    name      = "nginx-web"
    namespace = kubernetes_namespace.scalable_nginx.metadata[0].name
  }
  spec {
    selector = {
      App = kubernetes_deployment.nginx.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "web_ingress" {
  wait_for_load_balancer = true
  metadata {
    name      = "web-ingress"
    namespace = kubernetes_namespace.scalable_nginx.metadata[0].name
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.nginx_service.metadata.0.name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
