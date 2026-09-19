# Gitea — Git hosting + CI/CD (Actions) for pipeline credential demos

resource "kubernetes_namespace" "gitea" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "credentials-lab"
    }
  }
}

# Generate the Gitea admin password; never stored in state (ephemeral).
ephemeral "random_password" "gitea_admin" {
  length  = 24
  special = false
}

locals {
  gitea_admin_secret_revision = 1
}

# Admin credentials in a K8s Secret (write-only password). The chart reads them
# via gitea.admin.existingSecret instead of plaintext helm values — so the
# password is NOT rendered into the helm_release state.
resource "kubernetes_secret_v1" "gitea_admin" {
  metadata {
    name      = "gitea-admin"
    namespace = kubernetes_namespace.gitea.metadata[0].name
  }
  # data and data_wo are mutually exclusive on the same Secret, so everything
  # goes in data_wo (write-only). The username isn't secret, but keeping it here
  # keeps the whole Secret out of Terraform state.
  data_wo = {
    username = var.admin_username
    password = ephemeral.random_password.gitea_admin.result
  }
  data_wo_revision = local.gitea_admin_secret_revision
  type             = "Opaque"
}

# Durable copy in OpenBao (write-only). Retrieve the admin password from here
# rather than from git or state.
resource "vault_kv_secret_v2" "gitea_admin" {
  mount = var.openbao_kv_mount
  name  = var.openbao_kv_path

  data_json_wo = jsonencode({
    username = var.admin_username
    password = ephemeral.random_password.gitea_admin.result
  })
  data_json_wo_version = local.gitea_admin_secret_revision
}

resource "helm_release" "gitea" {
  name       = "gitea"
  repository = "https://dl.gitea.io/charts/"
  chart      = "gitea"
  version    = var.chart_version
  namespace  = kubernetes_namespace.gitea.metadata[0].name

  wait    = true
  timeout = 600

  values = [yamlencode({
    gitea = {
      admin = {
        # Credentials come from the Secret above, not plaintext values.
        existingSecret = kubernetes_secret_v1.gitea_admin.metadata[0].name
        email          = var.admin_email
        # initialOnlyNoReset: the admin password is set ONCE at creation and
        # never re-read afterward. This lets us delete the K8s Secret after
        # bootstrap (see harden-remove-gitea-secret.sh) — Gitea keeps its own
        # hashed credential, and the durable copy stays in OpenBao. With
        # keepUpdated the chart would re-read the Secret on every upgrade, so it
        # couldn't be removed.
        passwordMode = "initialOnlyNoReset"
      }
      config = {
        server = {
          DOMAIN      = "gitea.${var.domain}"
          ROOT_URL    = "http://gitea.${var.domain}/"
          HTTP_PORT   = 3000
          DISABLE_SSH = true
        }
        repository = {
          ENABLE_PUSH_CREATE_USER = true
          ENABLE_PUSH_CREATE_ORG  = true
        }
        packages = {
          ENABLED = true
        }
        actions = {
          ENABLED = true
        }
      }
      metrics = {
        enabled = false
      }
    }

    service = {
      http = {
        type = "ClusterIP"
      }
    }

    # Chart v12+ uses valkey (Redis fork). The cluster mode requires the
    # cluster bus port (16379) between nodes, which fails in dual-stack Kind.
    # Use single-node valkey instead.
    valkey-cluster = {
      enabled = false
    }
    valkey = {
      enabled = true
      architecture = "standalone"
    }
    postgresql-ha = {
      enabled = false
    }
    postgresql = {
      enabled = true
    }

    persistence = {
      enabled = true
      size    = "5Gi"
    }
  })]
}

# Expose Gitea via Gateway API HTTPRoute
resource "kubernetes_manifest" "gitea_httproute" {
  depends_on = [helm_release.gitea]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "gitea"
      namespace = var.namespace
    }
    spec = {
      parentRefs = [{
        name        = "shared-gateway"
        namespace   = "nginx-gateway"
        sectionName = "http"
      }]
      hostnames = ["gitea.${var.domain}"]
      rules = [{
        backendRefs = [{
          name = "gitea-http"
          port = 3000
        }]
      }]
    }
  }
}
