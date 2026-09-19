# OpenBao Server — HA deployment with Raft storage
# Deploys OpenBao via Helm chart in HA mode (3 replicas)

resource "kubernetes_namespace" "openbao" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "credentials-lab"
    }
  }
}

resource "helm_release" "openbao" {
  name       = "openbao"
  repository = "https://openbao.github.io/openbao-helm"
  chart      = "openbao"
  version    = var.chart_version
  namespace  = kubernetes_namespace.openbao.metadata[0].name

  wait    = true
  timeout = 600

  values = [yamlencode({
    server = {
      image = {
        registry   = "docker.io"
        repository = "openbao/openbao"
        tag        = var.openbao_version
      }

      # HA with Raft integrated storage
      ha = {
        enabled  = true
        replicas = var.replicas
        raft = {
          enabled   = true
          setNodeId = true
          config    = <<-EOT
            ui = true

            listener "tcp" {
              tls_disable     = 1
              address         = "[::]:8200"
              cluster_address = "[::]:8201"
            }

            storage "raft" {
              path = "/openbao/data"

              retry_join {
                leader_api_addr = "http://openbao-0.openbao-internal:8200"
              }
              retry_join {
                leader_api_addr = "http://openbao-1.openbao-internal:8200"
              }
              retry_join {
                leader_api_addr = "http://openbao-2.openbao-internal:8200"
              }
            }

            service_registration "kubernetes" {}

            # Declarative audit device. Modern OpenBao creates file/socket audit
            # devices from the server config (created on the active node at
            # start/SIGHUP) rather than the API, which is gated behind
            # unsafe_allow_api_audit_creation. This makes "audit enabled" part of
            # the deployed config instead of a manual post-deploy step.
            #
            # The stanza is keyed by TWO labels: type ("file") and the device
            # path ("file/"). The device settings (options) go inside.
            audit "file" "file/" {
              description = "File audit device (to stdout)"
              options = {
                # Write audit records to the pod's stdout. This needs no volume
                # or pre-created directory (the file audit device does NOT
                # create parent dirs), and it flows straight to Loki like the
                # rest of the series' logs. Use a real file_path only if you
                # mount a writable, pre-created directory.
                file_path = "stdout"
              }
            }

            # HA: cluster_addr is set per-node via VAULT_CLUSTER_ADDR env var
            # api_addr is set per-node via VAULT_API_ADDR env var
            # Request forwarding is enabled by default — standbys forward writes to leader
          EOT
        }
      }

      # Resource limits
      resources = {
        requests = {
          memory = "256Mi"
          cpu    = "250m"
        }
        limits = {
          memory = "512Mi"
        }
      }

      # Data persistence
      dataStorage = {
        enabled      = true
        size         = var.storage_size
        storageClass = var.storage_class
      }

      # Readiness/liveness probes
      readinessProbe = {
        enabled = true
        path    = "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
      }
      livenessProbe = {
        enabled             = true
        path                = "/v1/sys/health?standbyok=true"
        initialDelaySeconds = 60
      }
    }

    ui = {
      enabled = true
    }

    # CSI provider for Secrets Store CSI Driver integration
    csi = {
      enabled = var.enable_csi_provider
    }

    # Injector for sidecar-based secret injection
    injector = {
      enabled = var.enable_injector
      resources = {
        requests = {
          memory = "64Mi"
          cpu    = "50m"
        }
        limits = {
          memory = "128Mi"
        }
      }
    }
  })]
}

# Patch the Helm-created service to NodePort for local access (Kind)
resource "null_resource" "openbao_nodeport" {
  count = var.expose_nodeport ? 1 : 0

  depends_on = [helm_release.openbao]

  provisioner "local-exec" {
    command = "kubectl -n ${kubernetes_namespace.openbao.metadata[0].name} patch svc openbao-ui --type=merge -p '{\"spec\":{\"type\":\"NodePort\",\"ports\":[{\"name\":\"http\",\"port\":8200,\"targetPort\":8200,\"nodePort\":${var.nodeport}}]}}'"
  }

  triggers = {
    nodeport = var.nodeport
  }
}

# Expose OpenBao via Gateway API HTTPRoute
resource "kubernetes_manifest" "openbao_httproute" {
  count = var.expose_gateway ? 1 : 0

  depends_on = [helm_release.openbao]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "openbao"
      namespace = kubernetes_namespace.openbao.metadata[0].name
    }
    spec = {
      parentRefs = [{
        name        = "shared-gateway"
        namespace   = "nginx-gateway"
        sectionName = "http"
      }]
      hostnames = ["openbao.${var.gateway_domain}"]
      rules = [{
        backendRefs = [{
          name = "openbao-active"
          port = 8200
        }]
      }]
    }
  }
}
