# App-to-Database Demo (Part 3)
#
# Three workloads, three identities, three least-privilege JIT credential tiers:
#
#   1. api-migrator (Job, runs once): SA api-migrator -> OpenBao role api-migrate
#      -> db-migration. Short-TTL DDL creds; creates + seeds the schema, then the
#      Job completes. Nothing long-running ever holds DDL power.
#   2. api-reader (Deployment, GET /items): SA api-reader -> api-readonly ->
#      db-readonly. Read-only DB creds.
#   3. api-writer (Deployment, POST /items): SA api-writer -> api-readwrite ->
#      db-readwrite. Read/write DB creds.
#
# Ordering: the reader/writer Deployments depend_on the migration Job, and the
# kubernetes_job waits for completion — so the schema exists before either
# serves traffic.
#
# Routing: one hostname (api-server.<domain>); the HTTPRoute matches by HTTP
# method — GET -> api-reader, POST -> api-writer.

# --- Service accounts (one per identity/tier) ---

resource "kubernetes_service_account" "api_migrator" {
  metadata {
    name      = "api-migrator"
    namespace = var.namespace
  }
}

resource "kubernetes_service_account" "api_reader" {
  metadata {
    name      = "api-reader"
    namespace = var.namespace
  }
}

resource "kubernetes_service_account" "api_writer" {
  metadata {
    name      = "api-writer"
    namespace = var.namespace
  }
}

# --- Migration script (Job) ---

resource "kubernetes_config_map" "migrate_code" {
  metadata {
    name      = "api-migrate-code"
    namespace = var.namespace
  }

  data = {
    "migrate.py" = <<-PYEOF
      import os, requests, psycopg2

      VAULT_ADDR = os.environ["VAULT_ADDR"]
      DB_HOST    = os.environ["DB_HOST"]
      DB_NAME    = os.environ["DB_NAME"]
      SA = open("/var/run/secrets/kubernetes.io/serviceaccount/token").read()

      tok = requests.post(f"{VAULT_ADDR}/v1/auth/kubernetes/login",
                          json={"jwt": SA, "role": "api-migrate"}, timeout=5
            ).json()["auth"]["client_token"]
      d = requests.get(f"{VAULT_ADDR}/v1/database/creds/migration",
                       headers={"X-Vault-Token": tok}, timeout=5).json()["data"]
      print(f"migration running as {d['username']}")

      conn = psycopg2.connect(host=DB_HOST, dbname=DB_NAME,
                              user=d["username"], password=d["password"], connect_timeout=5)
      conn.autocommit = True
      with conn.cursor() as cur:
          # Idempotent: safe to re-run on every apply.
          cur.execute("CREATE TABLE IF NOT EXISTS items (id SERIAL PRIMARY KEY, name TEXT NOT NULL);")
          cur.execute("INSERT INTO items (name) SELECT v FROM (VALUES ('item-1'),('item-2'),('item-3')) AS s(v) WHERE NOT EXISTS (SELECT 1 FROM items);")
      conn.close()
      print("migration complete: items table ready")
    PYEOF
  }
}

resource "kubernetes_job" "migrate" {
  metadata {
    name      = "api-migrate"
    namespace = var.namespace
  }

  spec {
    backoff_limit = 3
    template {
      metadata {
        labels = { app = "api-migrate" }
      }
      spec {
        service_account_name = kubernetes_service_account.api_migrator.metadata[0].name
        restart_policy       = "OnFailure"

        container {
          name    = "migrate"
          image   = "python:3.12-slim"
          command = ["/bin/sh", "-c"]
          args    = ["pip install --quiet requests psycopg2-binary && python /app/migrate.py"]

          env {
            name  = "VAULT_ADDR"
            value = var.vault_internal_addr
          }
          env {
            name  = "DB_HOST"
            value = var.db_host
          }
          env {
            name  = "DB_NAME"
            value = var.db_name
          }

          volume_mount {
            name       = "migrate-code"
            mount_path = "/app"
          }
        }

        volume {
          name = "migrate-code"
          config_map {
            name = kubernetes_config_map.migrate_code.metadata[0].name
          }
        }
      }
    }
  }

  # Wait for the migration to actually COMPLETE (not just be created) before
  # Terraform moves on to the reader/writer Deployments.
  wait_for_completion = true
  timeouts {
    create = "5m"
  }
}

# --- Shared app code (reader + writer run the same code, different MODE) ---

resource "kubernetes_config_map" "api_code" {
  metadata {
    name      = "api-server-code"
    namespace = var.namespace
  }

  data = {
    "app.py" = <<-PYEOF
      import os
      import requests
      import psycopg2
      from flask import Flask, jsonify, request

      app = Flask(__name__)
      VAULT_ADDR = os.environ["VAULT_ADDR"]
      DB_HOST    = os.environ["DB_HOST"]
      DB_NAME    = os.environ["DB_NAME"]
      MODE       = os.environ.get("MODE", "read")            # "read" or "write"
      ROLE       = os.environ["VAULT_ROLE"]                  # api-readonly | api-readwrite
      DB_ROLE    = os.environ["DB_ROLE"]                     # readonly | readwrite
      SA_PATH    = "/var/run/secrets/kubernetes.io/serviceaccount/token"

      state = {"user": None, "pw": None}

      def vault_login():
          jwt = open(SA_PATH).read()
          r = requests.post(f"{VAULT_ADDR}/v1/auth/kubernetes/login",
                            json={"jwt": jwt, "role": ROLE}, timeout=5)
          r.raise_for_status()
          return r.json()["auth"]["client_token"]

      def refresh():
          tok = vault_login()
          r = requests.get(f"{VAULT_ADDR}/v1/database/creds/{DB_ROLE}",
                           headers={"X-Vault-Token": tok}, timeout=5)
          r.raise_for_status()
          d = r.json()["data"]
          state["user"], state["pw"] = d["username"], d["password"]
          app.logger.info(f"{MODE}: got db user {d['username']}")

      def connect():
          if not state["user"]:
              refresh()
          try:
              return psycopg2.connect(host=DB_HOST, dbname=DB_NAME,
                                      user=state["user"], password=state["pw"], connect_timeout=5)
          except psycopg2.OperationalError:
              refresh()  # creds may have rotated/expired
              return psycopg2.connect(host=DB_HOST, dbname=DB_NAME,
                                      user=state["user"], password=state["pw"], connect_timeout=5)

      @app.route("/items", methods=["GET"])
      def list_items():
          conn = connect()
          with conn.cursor() as cur:
              cur.execute("SELECT id, name FROM items ORDER BY id")
              rows = cur.fetchall()
          conn.close()
          return jsonify({"tier": MODE, "db_user": state["user"],
                          "items": [{"id": r[0], "name": r[1]} for r in rows]})

      @app.route("/items", methods=["POST"])
      def add_item():
          # Only the writer serves POST; if the reader is somehow hit with POST,
          # its readonly DB creds cannot INSERT and Postgres rejects it — a live
          # demonstration of least privilege.
          name = (request.get_json(silent=True) or {}).get("name")
          if not name:
              return jsonify({"error": "provide JSON {\"name\": \"...\"}"}), 400
          conn = connect()
          conn.autocommit = True
          with conn.cursor() as cur:
              cur.execute("INSERT INTO items (name) VALUES (%s) RETURNING id", (name,))
              new_id = cur.fetchone()[0]
          conn.close()
          return jsonify({"tier": MODE, "db_user": state["user"],
                          "added": {"id": new_id, "name": name}}), 201

      @app.route("/whoami")
      def whoami():
          return jsonify({"mode": MODE, "db_user": state["user"]})

      @app.route("/healthz")
      def healthz():
          return "ok"

      if __name__ == "__main__":
          app.run(host="0.0.0.0", port=8080)
    PYEOF
  }
}

# --- Reader Deployment (GET) ---

resource "kubernetes_deployment" "api_reader" {
  metadata {
    name      = "api-reader"
    namespace = var.namespace
    labels    = { app = "api-reader" }
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = { app = "api-reader" }
    }
    template {
      metadata {
        labels = { app = "api-reader" }
      }
      spec {
        service_account_name = kubernetes_service_account.api_reader.metadata[0].name
        container {
          name    = "api"
          image   = "python:3.12-slim"
          command = ["/bin/sh", "-c"]
          args    = ["pip install --quiet flask requests psycopg2-binary && python /app/app.py"]

          env {
            name  = "VAULT_ADDR"
            value = var.vault_internal_addr
          }
          env {
            name  = "DB_HOST"
            value = var.db_host
          }
          env {
            name  = "DB_NAME"
            value = var.db_name
          }
          env {
            name  = "MODE"
            value = "read"
          }
          env {
            name  = "VAULT_ROLE"
            value = "api-readonly"
          }
          env {
            name  = "DB_ROLE"
            value = "readonly"
          }

          port {
            container_port = 8080
          }
          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 25
            period_seconds        = 10
          }
          volume_mount {
            name       = "code"
            mount_path = "/app"
          }
        }
        volume {
          name = "code"
          config_map {
            name = kubernetes_config_map.api_code.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_job.migrate]
}

# --- Writer Deployment (POST) ---

resource "kubernetes_deployment" "api_writer" {
  metadata {
    name      = "api-writer"
    namespace = var.namespace
    labels    = { app = "api-writer" }
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = { app = "api-writer" }
    }
    template {
      metadata {
        labels = { app = "api-writer" }
      }
      spec {
        service_account_name = kubernetes_service_account.api_writer.metadata[0].name
        container {
          name    = "api"
          image   = "python:3.12-slim"
          command = ["/bin/sh", "-c"]
          args    = ["pip install --quiet flask requests psycopg2-binary && python /app/app.py"]

          env {
            name  = "VAULT_ADDR"
            value = var.vault_internal_addr
          }
          env {
            name  = "DB_HOST"
            value = var.db_host
          }
          env {
            name  = "DB_NAME"
            value = var.db_name
          }
          env {
            name  = "MODE"
            value = "write"
          }
          env {
            name  = "VAULT_ROLE"
            value = "api-readwrite"
          }
          env {
            name  = "DB_ROLE"
            value = "readwrite"
          }

          port {
            container_port = 8080
          }
          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 25
            period_seconds        = 10
          }
          volume_mount {
            name       = "code"
            mount_path = "/app"
          }
        }
        volume {
          name = "code"
          config_map {
            name = kubernetes_config_map.api_code.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_job.migrate]
}

# --- Services ---

resource "kubernetes_service" "api_reader" {
  metadata {
    name      = "api-reader"
    namespace = var.namespace
  }
  spec {
    selector = { app = "api-reader" }
    port {
      port        = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_service" "api_writer" {
  metadata {
    name      = "api-writer"
    namespace = var.namespace
  }
  spec {
    selector = { app = "api-writer" }
    port {
      port        = 8080
      target_port = 8080
    }
  }
}

# --- HTTPRoute: one host, method-based routing (GET -> reader, POST -> writer) ---

resource "kubernetes_manifest" "api_server_httproute" {
  count = var.expose_gateway ? 1 : 0

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "api-server"
      namespace = var.namespace
    }
    spec = {
      parentRefs = [{
        name        = "shared-gateway"
        namespace   = "nginx-gateway"
        sectionName = "http"
      }]
      hostnames = ["api-server.${var.gateway_domain}"]
      rules = [
        {
          # WRITE path: POST /items -> writer (readwrite creds).
          matches = [{
            method = "POST"
            path   = { type = "PathPrefix", value = "/items" }
          }]
          backendRefs = [{
            name = kubernetes_service.api_writer.metadata[0].name
            port = 8080
          }]
        },
        {
          # READ path: GET /items -> reader (readonly creds). Explicit method+path
          # so it matches reliably (a bare "/" catch-all next to a method-specific
          # rule doesn't match consistently on NGINX Gateway Fabric).
          matches = [{
            method = "GET"
            path   = { type = "PathPrefix", value = "/items" }
          }]
          backendRefs = [{
            name = kubernetes_service.api_reader.metadata[0].name
            port = 8080
          }]
        },
        {
          # Fallback for the reader's other GET endpoints (/whoami, /healthz).
          matches = [
            { method = "GET", path = { type = "PathPrefix", value = "/whoami" } },
            { method = "GET", path = { type = "PathPrefix", value = "/healthz" } },
          ]
          backendRefs = [{
            name = kubernetes_service.api_reader.metadata[0].name
            port = 8080
          }]
        },
      ]
    }
  }
}
