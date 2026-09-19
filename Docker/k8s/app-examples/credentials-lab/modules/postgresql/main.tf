# PostgreSQL for the Part 3 database secrets engine demo.
# Single instance in its own namespace so Part 3 is self-contained
# (independent of the Part 2 credentials-demo namespace).

resource "kubernetes_namespace" "db_demo" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "credentials-lab"
    }
  }
}

# Generate the postgres admin password; never stored in state (ephemeral).
ephemeral "random_password" "pg_admin" {
  length  = 24
  special = false
}

locals {
  pg_secret_revision = 1
}

resource "kubernetes_secret_v1" "postgres" {
  metadata {
    name      = "postgres-admin"
    namespace = kubernetes_namespace.db_demo.metadata[0].name
  }
  # data and data_wo are mutually exclusive on the same Secret, so all three
  # keys go in data_wo (write-only). Only POSTGRES_PASSWORD is truly secret, but
  # keeping user/db here too keeps the whole Secret out of Terraform state.
  data_wo = {
    POSTGRES_USER     = var.admin_user
    POSTGRES_DB       = var.database
    POSTGRES_PASSWORD = ephemeral.random_password.pg_admin.result
  }
  data_wo_revision = local.pg_secret_revision
  type             = "Opaque"
}

# Durable home for the admin password: OpenBao KV (write-only — KV is the source
# of truth, not state). The openbao-database module reads this back ephemerally
# to configure the database secrets engine connection.
resource "vault_kv_secret_v2" "pg_admin" {
  mount = var.openbao_kv_mount
  name  = var.openbao_kv_path

  data_json_wo = jsonencode({
    username = var.admin_user
    password = ephemeral.random_password.pg_admin.result
  })
  data_json_wo_version = local.pg_secret_revision
}

# Seed SQL: create a demo table so read/write roles have something to touch.
resource "kubernetes_config_map" "postgres_init" {
  metadata {
    name      = "postgres-init"
    namespace = kubernetes_namespace.db_demo.metadata[0].name
  }
  data = {
    # Schema is created by the demo app's MIGRATION init-container (Part 3),
    # which authenticates to OpenBao as the api-migrator SA, fetches short-TTL
    # DDL credentials, and runs the migration — so the app's own credentials
    # never need DDL power. We deliberately do NOT seed the schema here via
    # Postgres's docker-entrypoint-initdb.d; the DB starts empty and the
    # migration owns the `items` table. (Left as a no-op so the volume wiring
    # stays intact and easy to repurpose.)
    "init.sql" = "-- intentionally empty: schema is created by the app migration init-container\n"
  }
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.db_demo.metadata[0].name
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
          image = "postgres:16-alpine"

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.postgres.metadata[0].name
            }
          }

          # Store data under a subdir so the init scripts run on an empty DB.
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          port {
            container_port = 5432
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }
          volume_mount {
            name       = "init"
            mount_path = "/docker-entrypoint-initdb.d"
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.admin_user, "-d", var.database]
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }

        volume {
          name = "data"
          empty_dir {}
        }
        volume {
          name = "init"
          config_map {
            name = kubernetes_config_map.postgres_init.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.db_demo.metadata[0].name
  }
  spec {
    selector = { app = "postgres" }
    port {
      port        = 5432
      target_port = 5432
    }
  }
}
