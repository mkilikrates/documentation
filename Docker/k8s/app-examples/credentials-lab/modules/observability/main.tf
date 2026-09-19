# Observability module (Part 5) — Loki + Alloy + Grafana for credential leak detection
#
# This is a lean, self-contained logging stack for the lab. It is intentionally
# a subset of the full "Kubernetes Observability with Grafana Stack" series
# (which also ships Prometheus + Tempo). For Part 5 we only need:
#
#   Alloy   — tails every pod's stdout and pushes to Loki with namespace/pod/
#             container/app labels. OpenBao's audit device already writes JSON
#             to stdout (see modules/openbao-server), so audit records flow to
#             Loki with NO extra wiring — they are just pod logs.
#   Loki    — single-binary, filesystem storage (no S3/MinIO needed for a lab).
#   Grafana — Loki datasource pre-provisioned + a unified alerting contact point.
#
# If you already ran the Observability series stack in this cluster, you can set
# install_loki/install_alloy/install_grafana = false and point the Part 5 alert
# module at your existing Grafana instead.

resource "kubernetes_namespace" "monitoring" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "credentials-lab"
    }
  }
}

locals {
  namespace = var.create_namespace ? kubernetes_namespace.monitoring[0].metadata[0].name : var.namespace
}

# ---------------------------------------------------------------------------
# Loki — single-binary, filesystem storage (mirrors monitoring/loki-values.yaml)
# ---------------------------------------------------------------------------
resource "helm_release" "loki" {
  count = var.install_loki ? 1 : 0

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_chart_version
  namespace  = local.namespace

  wait    = true
  timeout = 600

  values = [yamlencode({
    deploymentMode = "SingleBinary"
    loki = {
      auth_enabled = false
      commonConfig = { replication_factor = 1 }
      schemaConfig = {
        configs = [{
          from         = "2024-01-01"
          store        = "tsdb"
          object_store = "filesystem"
          schema       = "v13"
          index        = { prefix = "loki_index_", period = "24h" }
        }]
      }
      storage      = { type = "filesystem" }
      limits_config = { retention_period = "72h" }
    }
    singleBinary = {
      replicas    = 1
      persistence = { size = "5Gi" }
    }
    # Disable components not used in single-binary mode
    backend       = { replicas = 0 }
    read          = { replicas = 0 }
    write         = { replicas = 0 }
    gateway       = { enabled = false }
    chunksCache   = { enabled = false }
    resultsCache  = { enabled = false }
  })]

  depends_on = [kubernetes_namespace.monitoring]
}

# ---------------------------------------------------------------------------
# Alloy — collects all pod logs (incl. OpenBao audit stdout) and pushes to Loki
# (mirrors monitoring/alloy-values.yaml, trimmed to the log pipeline)
# ---------------------------------------------------------------------------
resource "helm_release" "alloy" {
  count = var.install_alloy ? 1 : 0

  name       = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.alloy_chart_version
  namespace  = local.namespace

  wait    = true
  timeout = 600

  values = [yamlencode({
    alloy = {
      configMap = {
        content = <<-ALLOY
          // Discover all pods
          discovery.kubernetes "pod" {
            role = "pod"
          }

          // Relabel Kubernetes metadata into queryable labels
          discovery.relabel "pod_logs" {
            targets = discovery.kubernetes.pod.targets

            rule {
              source_labels = ["__meta_kubernetes_namespace"]
              action        = "replace"
              target_label  = "namespace"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_name"]
              action        = "replace"
              target_label  = "pod"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_container_name"]
              action        = "replace"
              target_label  = "container"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
              action        = "replace"
              target_label  = "app"
            }
          }

          // Tail logs from discovered pods
          loki.source.kubernetes "pod_logs" {
            targets    = discovery.relabel.pod_logs.output
            forward_to = [loki.process.pod_logs.receiver]
          }

          // Add a static cluster label
          loki.process "pod_logs" {
            stage.static_labels {
              values = { cluster = "kind" }
            }
            forward_to = [loki.write.default.receiver]
          }

          // Loki write endpoint
          loki.write "default" {
            endpoint {
              url = "http://loki.${local.namespace}:3100/loki/api/v1/push"
            }
          }
        ALLOY
      }
    }
  })]

  depends_on = [helm_release.loki]
}

# ---------------------------------------------------------------------------
# Grafana — standalone, Loki datasource pre-provisioned
# ---------------------------------------------------------------------------
resource "helm_release" "grafana" {
  count = var.install_grafana ? 1 : 0

  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.grafana_chart_version
  namespace  = local.namespace

  wait    = true
  timeout = 600

  values = [yamlencode({
    # Admin password is generated by the caller (write-only, from OpenBao) and
    # passed via existingSecret so it is NOT rendered into Helm release state.
    admin = {
      existingSecret = var.grafana_admin_secret_name
      userKey        = "admin-user"
      passwordKey    = "admin-password"
    }

    datasources = {
      "datasources.yaml" = {
        apiVersion = 1
        datasources = [{
          name      = "Loki"
          type      = "loki"
          uid       = "loki"
          access    = "proxy"
          url       = "http://loki.${local.namespace}:3100"
          isDefault = true
        }]
      }
    }

    # Expose Grafana via Gateway API HTTPRoute (optional, same pattern as apps)
    service = { type = "ClusterIP" }
  })]

  depends_on = [helm_release.loki, kubernetes_secret_v1.grafana_admin]
}

# ---------------------------------------------------------------------------
# Grafana admin credential — generated, write-only, stored in OpenBao.
# Same hygiene as every other password in the lab (see postgresql module):
# the password is generated as an EPHEMERAL value so it never enters state,
# then fed only into write-only attributes (the K8s Secret and the OpenBao KV).
# ---------------------------------------------------------------------------
ephemeral "random_password" "grafana_admin" {
  length  = 24
  special = false
}

locals {
  grafana_secret_revision = 1
}

resource "kubernetes_secret_v1" "grafana_admin" {
  count = var.install_grafana ? 1 : 0

  metadata {
    name      = var.grafana_admin_secret_name
    namespace = local.namespace
  }

  # Write-only: the generated password is never stored in state.
  data_wo = {
    "admin-user"     = "admin"
    "admin-password" = ephemeral.random_password.grafana_admin.result
  }
  data_wo_revision = local.grafana_secret_revision

  type = "Opaque"
}

# Durable home for the Grafana admin credential: OpenBao KV (write-only — KV is
# the source of truth, not state). Lets you remove the K8s Secret post-bootstrap
# and retrieve the password later, same lifecycle as the other parts.
resource "vault_kv_secret_v2" "grafana_admin" {
  count = var.install_grafana && var.store_admin_in_openbao ? 1 : 0

  mount = var.openbao_kv_mount
  name  = var.openbao_kv_path

  data_json_wo = jsonencode({
    username = "admin"
    password = ephemeral.random_password.grafana_admin.result
    url      = "http://grafana.${local.namespace}:80"
  })
  data_json_wo_version = local.grafana_secret_revision
}

# HTTPRoute to reach Grafana in the browser (http://grafana.<domain>)
resource "kubernetes_manifest" "grafana_httproute" {
  count = var.install_grafana && var.expose_gateway ? 1 : 0

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "grafana"
      namespace = local.namespace
    }
    spec = {
      parentRefs = [{
        name        = "shared-gateway"
        namespace   = "nginx-gateway"
        sectionName = "http"
      }]
      hostnames = ["grafana.${var.gateway_domain}"]
      rules = [{
        backendRefs = [{
          name = "grafana"
          port = 80
        }]
      }]
    }
  }

  depends_on = [helm_release.grafana]
}
