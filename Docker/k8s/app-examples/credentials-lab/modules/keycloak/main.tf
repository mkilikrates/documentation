# Keycloak (Part 4) — OIDC Identity Provider for human authentication.
#
# This mirrors the OFFICIAL Keycloak Kubernetes quickstart
# (https://www.keycloak.org/getting-started/getting-started-kube), which ships
# plain manifests (a StatefulSet + Services + a bundled PostgreSQL) rather than
# a Helm chart — Keycloak has no official Helm chart. We reproduce those
# manifests natively with the kubernetes provider and adapt them to the lab:
# our own namespace, a single replica to save resources, configurable admin
# credentials/version, and exposure through the shared Gateway API instead of
# the minikube Ingress the upstream guide uses.
#
# Storage is ephemeral (matching the upstream test manifest). That is fine here:
# the realm, client, users and groups are declared as code in the
# keycloak-config module, so a restart is fully recoverable by re-applying.

resource "kubernetes_namespace" "keycloak" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "credentials-lab"
    }
  }
}

# --- Bootstrap admin password: generated, never stored in state ---
#
# ephemeral random_password is generated fresh each run and never written to
# state or plan. We hand it to a Kubernetes Secret via a write-only argument
# (data_wo) and store the durable copy in OpenBao KV (also write-only). Nothing
# sensitive lands in terraform.tfstate. This is the "Secret Zero" for Keycloak:
# a generated, short-lived bootstrap credential kept in OpenBao, not in git.
ephemeral "random_password" "kc_admin" {
  length           = 24
  special          = true
  override_special = "-_."
}

# Track a revision so rotating the password (bumping this) re-writes the Secret.
locals {
  kc_admin_secret_revision = 1
}

# Kubernetes Secret holding the bootstrap admin password (write-only: the value
# is consumed by the API and NOT persisted in state).
resource "kubernetes_secret_v1" "kc_admin" {
  metadata {
    name      = "keycloak-bootstrap-admin"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  data_wo = {
    username = var.admin_user
    password = ephemeral.random_password.kc_admin.result
  }
  data_wo_revision = local.kc_admin_secret_revision

  type = "Opaque"
}

# Durable home for the credential: OpenBao KV. Written with a write-only
# argument so the secret is not tracked in state — OpenBao is the source of
# truth. keycloak-config reads this back ephemerally to authenticate.
resource "vault_kv_secret_v2" "kc_admin" {
  mount = var.openbao_kv_mount
  name  = var.openbao_kv_path

  data_json_wo          = jsonencode({
    username = var.admin_user
    password = ephemeral.random_password.kc_admin.result
  })
  data_json_wo_version = local.kc_admin_secret_revision
}

# --- Keycloak's database password: generated, not stored in state ---
ephemeral "random_password" "kc_db" {
  length  = 24
  special = false
}

resource "kubernetes_secret_v1" "kc_db" {
  metadata {
    name      = "keycloak-db"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }
  data_wo = {
    password = ephemeral.random_password.kc_db.result
  }
  data_wo_revision = local.kc_admin_secret_revision
  type             = "Opaque"
}

# --- PostgreSQL (bundled, ephemeral — as in the upstream quickstart) ---

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
    labels    = { app = "postgres" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "postgres" }
    }
    template {
      metadata {
        labels = { app = "postgres" }
      }
      spec {
        container {
          name  = "postgres"
          image = var.postgres_image

          env {
            name  = "POSTGRES_USER"
            value = var.db_user
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.kc_db.metadata[0].name
                key  = "password"
              }
            }
          }
          env {
            name  = "POSTGRES_DB"
            value = var.db_name
          }

          port {
            name           = "postgres"
            container_port = 5432
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.db_user, "-d", var.db_name]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }

        volume {
          name = "postgres-data"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
    labels    = { app = "postgres" }
  }
  spec {
    selector = { app = "postgres" }
    port {
      protocol    = "TCP"
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

# --- Keycloak Services (http + headless discovery, per upstream) ---

resource "kubernetes_service" "keycloak" {
  metadata {
    name      = "keycloak"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
    labels    = { app = "keycloak" }
  }
  spec {
    selector = { app = "keycloak" }
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 8080
      target_port = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "keycloak_discovery" {
  metadata {
    name      = "keycloak-discovery"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
    labels    = { app = "keycloak" }
  }
  spec {
    selector   = { app = "keycloak" }
    cluster_ip = "None"
    type       = "ClusterIP"
  }
}

# --- Keycloak StatefulSet (faithful to upstream, single replica for the lab) ---

resource "kubernetes_stateful_set" "keycloak" {
  metadata {
    name      = "keycloak"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
    labels    = { app = "keycloak" }
  }

  spec {
    service_name = kubernetes_service.keycloak_discovery.metadata[0].name
    replicas     = var.replicas

    selector {
      match_labels = { app = "keycloak" }
    }

    template {
      metadata {
        labels = { app = "keycloak" }
      }
      spec {
        container {
          name  = "keycloak"
          image = "quay.io/keycloak/keycloak:${var.keycloak_version}"
          args  = ["start"]

          env {
            name = "KC_BOOTSTRAP_ADMIN_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.kc_admin.metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "KC_BOOTSTRAP_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.kc_admin.metadata[0].name
                key  = "password"
              }
            }
          }
          # Sit behind the shared gateway (reverse proxy); trust its headers.
          env {
            name  = "KC_PROXY_HEADERS"
            value = "xforwarded"
          }
          env {
            name  = "KC_HTTP_ENABLED"
            value = "true"
          }
          # Pin the public hostname so the OIDC issuer in tokens is stable and
          # identical whether reached via the browser (external) or by OpenBao's
          # discovery call. Without this, the issuer would vary by request host
          # and OpenBao's bound_issuer check would fail. See the openbao-oidc
          # module, whose oidc_discovery_url/bound_issuer use this same URL.
          env {
            name  = "KC_HOSTNAME"
            value = "http://keycloak.${var.gateway_domain}"
          }
          env {
            name  = "KC_HOSTNAME_STRICT"
            value = "false"
          }
          env {
            name  = "KC_HEALTH_ENABLED"
            value = "true"
          }
          # Local cache — single replica, no JGroups clustering needed for the lab.
          env {
            name  = "KC_CACHE"
            value = "local"
          }
          env {
            name  = "KC_DB"
            value = "postgres"
          }
          env {
            name  = "KC_DB_URL_HOST"
            value = kubernetes_service.postgres.metadata[0].name
          }
          env {
            name  = "KC_DB_URL_DATABASE"
            value = var.db_name
          }
          env {
            name  = "KC_DB_USERNAME"
            value = var.db_user
          }
          env {
            name = "KC_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.kc_db.metadata[0].name
                key  = "password"
              }
            }
          }

          port {
            name           = "http"
            container_port = 8080
          }

          startup_probe {
            http_get {
              path = "/health/started"
              port = 9000
            }
            period_seconds    = 5
            failure_threshold = 120
          }
          readiness_probe {
            http_get {
              path = "/health/ready"
              port = 9000
            }
            period_seconds    = 10
            failure_threshold = 3
          }
          liveness_probe {
            http_get {
              path = "/health/live"
              port = 9000
            }
            period_seconds    = 10
            failure_threshold = 3
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1024Mi"
            }
            limits = {
              memory = "1500Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.postgres]
}

# --- Expose Keycloak via the shared gateway (native manifest, not local-exec) ---

resource "kubernetes_manifest" "keycloak_httproute" {
  count = var.expose_gateway ? 1 : 0

  depends_on = [kubernetes_stateful_set.keycloak]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "keycloak"
      namespace = kubernetes_namespace.keycloak.metadata[0].name
    }
    spec = {
      parentRefs = [{
        name        = "shared-gateway"
        namespace   = "nginx-gateway"
        sectionName = "http"
      }]
      hostnames = ["keycloak.${var.gateway_domain}"]
      rules = [{
        backendRefs = [{
          name = kubernetes_service.keycloak.metadata[0].name
          port = 8080
        }]
      }]
    }
  }
}
