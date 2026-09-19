# Service-to-Service Demo App (Part 2)
# Frontend requests a JWT from OpenBao and calls Backend with it.
# Backend validates the JWT against OpenBao's JWKS endpoint.
#
# Uses a stock python image + inline scripts (no custom image build needed).

resource "kubernetes_namespace" "demo" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "credentials-lab"
    }
  }
}

# --- Service Accounts (these names must match the OpenBao k8s auth roles) ---

resource "kubernetes_service_account" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
}

resource "kubernetes_service_account" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
}

# --- Backend: validates JWTs against OpenBao JWKS ---

# spiffe-helper config: fetch the SVID over the Workload API socket and write
# svid.pem / svid_key.pem / svid_bundle.pem to /certs, keeping them rotated.
resource "kubernetes_config_map" "backend_helper" {
  metadata {
    name      = "backend-helper-config"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
  data = {
    "helper.conf" = <<-EOT
      agent_address       = "/spiffe-workload-api/spire-agent.sock"
      cert_dir            = "/certs"
      svid_file_name      = "svid.pem"
      svid_key_file_name  = "svid_key.pem"
      svid_bundle_file_name = "svid_bundle.pem"
      key_file_mode       = 0644
      daemon_mode         = true
    EOT
  }
}

resource "kubernetes_config_map" "backend_code" {
  metadata {
    name      = "backend-code"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }

  data = {
    # Two-layer auth (defence in depth):
    #   1) mTLS TRANSPORT GATE — require a client cert, then verify the caller's
    #      SPIFFE ID (from the cert URI SAN) is on the allow-list. This answers
    #      "who may connect at all" and rejects any workload that isn't the
    #      frontend, BEFORE any application logic runs.
    #   2) OpenBao JWT — authn/authz for the request: verify signature +
    #      audience + the "service" claim.
    # We run a small ssl-wrapped HTTP server so we can read the actual peer
    # certificate per connection (Flask's dev server doesn't expose it reliably).
    "app.py" = <<-PYEOF
      import os, json, ssl, logging
      from functools import lru_cache
      from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
      import jwt
      import requests
      from cryptography import x509
      from cryptography.x509.oid import ExtensionOID

      logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
      log = logging.getLogger("backend")

      VAULT_ADDR = os.environ["VAULT_ADDR"]
      JWKS_URL = f"{VAULT_ADDR}/v1/identity/oidc/.well-known/keys"
      ALLOWED_CALLERS = ["frontend"]                       # JWT "service" claim
      EXPECTED_AUDIENCE = "backend-api"                    # OIDC role client_id
      ALLOWED_SPIFFE_IDS = [s for s in os.environ.get("ALLOWED_SPIFFE_IDS", "").split(",") if s]

      @lru_cache(maxsize=1)
      def get_jwks():
          return requests.get(JWKS_URL, timeout=5).json()

      def validate_jwt(token):
          kid = jwt.get_unverified_header(token).get("kid")
          for _ in range(2):
              for k in get_jwks()["keys"]:
                  if k["kid"] == kid:
                      key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(k))
                      return jwt.decode(token, key, algorithms=["RS256"], audience=EXPECTED_AUDIENCE)
              get_jwks.cache_clear()  # keys may have rotated; refresh once
          raise ValueError(f"key {kid} not found in JWKS")

      def spiffe_id_from_der(der_bytes):
          """Extract the SPIFFE ID (URI SAN) from the peer's DER certificate."""
          cert = x509.load_der_x509_certificate(der_bytes)
          san = cert.extensions.get_extension_for_oid(ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
          for uri in san.value.get_values_for_type(x509.UniformResourceIdentifier):
              if uri.startswith("spiffe://"):
                  return uri
          return None

      class Handler(BaseHTTPRequestHandler):
          def _json(self, code, body):
              self.send_response(code)
              self.send_header("Content-Type", "application/json")
              self.end_headers()
              self.wfile.write(json.dumps(body).encode())

          def do_GET(self):
              if self.path == "/healthz":
                  return self._json(200, {"status": "ok"})

              # --- Layer 1: mTLS transport gate — verify the client SPIFFE ID ---
              der = self.connection.getpeercert(binary_form=True)
              if not der:
                  return self._json(401, {"error": "no client certificate (mTLS required)"})
              caller_spiffe = spiffe_id_from_der(der)
              if caller_spiffe not in ALLOWED_SPIFFE_IDS:
                  log.warning(f"rejected SPIFFE ID: {caller_spiffe}")
                  return self._json(403, {"error": f"SPIFFE ID '{caller_spiffe}' not allowed"})

              if self.path != "/data":
                  return self._json(404, {"error": "not found"})

              # --- Layer 2: OpenBao JWT — authn/authz for the request ---
              auth = self.headers.get("Authorization", "")
              if not auth.startswith("Bearer "):
                  return self._json(401, {"error": "missing bearer token"})
              try:
                  claims = validate_jwt(auth[7:])
              except Exception as e:
                  return self._json(403, {"error": f"jwt validation failed: {e}"})
              if claims.get("service", "") not in ALLOWED_CALLERS:
                  return self._json(403, {"error": "caller not authorized"})

              return self._json(200, {
                  "service": "backend",
                  "data": ["item-1", "item-2", "item-3"],
                  "mtls_caller_spiffe_id": caller_spiffe,
                  "jwt_caller": claims.get("service"),
                  "message": "authorized via mTLS SPIFFE identity + OpenBao JWT",
              })

          def log_message(self, *a):  # quieter logs
              pass

      # SVIDs are short-lived and rotated by the spiffe-helper (it rewrites
      # /certs every ~half of the SVID lifetime). A TLS server must therefore
      # RELOAD its cert — wrapping the listener socket once at startup would
      # keep serving the cert loaded at boot, which expires within hours and
      # breaks mTLS. We rebuild the SSLContext whenever svid.pem changes (cheap:
      # only on rotation) and wrap each accepted connection with the fresh one.
      _ssl_state = {"mtime": 0.0, "ctx": None}

      def current_ssl_context():
          m = os.path.getmtime("/certs/svid.pem")
          if m != _ssl_state["mtime"]:
              ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
              ctx.load_cert_chain("/certs/svid.pem", "/certs/svid_key.pem")
              ctx.load_verify_locations("/certs/svid_bundle.pem")
              ctx.verify_mode = ssl.CERT_REQUIRED      # require a client cert (mTLS)
              _ssl_state.update(mtime=m, ctx=ctx)
              log.info("(re)loaded server SVID from /certs/svid.pem")
          return _ssl_state["ctx"]

      class MTLSServer(ThreadingHTTPServer):
          # Wrap each new connection with the CURRENT context, so rotated certs
          # are picked up without restarting the server.
          def get_request(self):
              sock, addr = self.socket.accept()
              tls = current_ssl_context().wrap_socket(sock, server_side=True)
              return tls, addr

      if __name__ == "__main__":
          current_ssl_context()  # fail fast if certs aren't ready yet
          srv = MTLSServer(("0.0.0.0", 8443), Handler)
          log.info(f"backend mTLS listening on :8443; allowed SPIFFE IDs: {ALLOWED_SPIFFE_IDS}")
          srv.serve_forever()
    PYEOF
  }
}

resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.demo.metadata[0].name
    labels    = { app = "backend" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "backend" }
    }
    template {
      metadata {
        labels = { app = "backend" }
      }
      spec {
        service_account_name = kubernetes_service_account.backend.metadata[0].name

        # Install python deps once into a shared volume (keeps the app container
        # start command simple and avoids re-installing on every restart loop).
        init_container {
          name    = "install-deps"
          image   = "python:3.12-slim"
          command = ["pip", "install", "--target=/packages", "flask", "requests", "pyjwt[crypto]", "cryptography"]
          volume_mount {
            name       = "packages"
            mount_path = "/packages"
          }
        }

        container {
          name    = "backend"
          image   = "python:3.12-slim"
          command = ["/bin/sh", "-c"]
          # Wait for the spiffe-helper to write the SVID, then run the mTLS server.
          args = [
            "while [ ! -f /certs/svid.pem ]; do echo waiting for SVID; sleep 2; done; export PYTHONPATH=/packages; python /app/app.py"
          ]

          env {
            name  = "VAULT_ADDR"
            value = var.vault_internal_addr
          }
          # Only this SPIFFE ID (the frontend) may connect over mTLS.
          env {
            name  = "ALLOWED_SPIFFE_IDS"
            value = "spiffe://${var.trust_domain}/ns/${var.namespace}/sa/frontend"
          }

          port {
            container_port = 8443
          }

          volume_mount {
            name       = "code"
            mount_path = "/app"
          }
          volume_mount {
            name       = "packages"
            mount_path = "/packages"
          }
          volume_mount {
            name       = "certs"
            mount_path = "/certs"
          }
        }

        # SPIFFE helper: fetches + rotates the SVID from the Workload API socket.
        container {
          name  = "spiffe-helper"
          image = var.spiffe_helper_image
          args  = ["-config", "/config/helper.conf"]
          volume_mount {
            name       = "spiffe-workload-api"
            mount_path = "/spiffe-workload-api"
            read_only  = true
          }
          volume_mount {
            name       = "certs"
            mount_path = "/certs"
          }
          volume_mount {
            name       = "helper-config"
            mount_path = "/config"
          }
        }

        volume {
          name = "code"
          config_map {
            name = kubernetes_config_map.backend_code.metadata[0].name
          }
        }
        volume {
          name = "helper-config"
          config_map {
            name = kubernetes_config_map.backend_helper.metadata[0].name
          }
        }
        volume {
          name = "packages"
          empty_dir {}
        }
        volume {
          name = "certs"
          empty_dir {}
        }
        # SPIFFE Workload API socket, delivered by the SPIFFE CSI driver.
        volume {
          name = "spiffe-workload-api"
          csi {
            driver    = "csi.spiffe.io"
            read_only = true
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
  spec {
    selector = { app = "backend" }
    port {
      name        = "mtls"
      port        = 8443
      target_port = 8443
    }
  }
}

# --- Frontend: authenticates to OpenBao, requests JWT, calls backend ---

resource "kubernetes_config_map" "frontend_helper" {
  metadata {
    name      = "frontend-helper-config"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
  data = {
    "helper.conf" = <<-EOT
      agent_address       = "/spiffe-workload-api/spire-agent.sock"
      cert_dir            = "/certs"
      svid_file_name      = "svid.pem"
      svid_key_file_name  = "svid_key.pem"
      svid_bundle_file_name = "svid_bundle.pem"
      key_file_mode       = 0644
      daemon_mode         = true
    EOT
  }
}

resource "kubernetes_config_map" "frontend_code" {
  metadata {
    name      = "frontend-code"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }

  data = {
    # The frontend does BOTH: presents its SVID as a client cert (mTLS) AND
    # attaches an OpenBao-issued JWT. The backend enforces both layers.
    "app.py" = <<-PYEOF
      import os, time, ssl, json
      import urllib.request
      import requests
      from flask import Flask, jsonify

      app = Flask(__name__)
      VAULT_ADDR = os.environ["VAULT_ADDR"]
      BACKEND_URL = os.environ["BACKEND_URL"]   # https://backend...:8443
      SA_TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"

      class Vault:
          def __init__(self):
              self.token = None
              self.expiry = 0

          def authenticate(self):
              with open(SA_TOKEN_PATH) as f:
                  sa = f.read()
              r = requests.post(f"{VAULT_ADDR}/v1/auth/kubernetes/login",
                                json={"jwt": sa, "role": "frontend"}, timeout=5)
              r.raise_for_status()
              a = r.json()["auth"]
              self.token = a["client_token"]
              self.expiry = time.time() + a["lease_duration"]

          def get_jwt(self):
              if not self.token or time.time() > self.expiry - 60:
                  self.authenticate()
              r = requests.get(f"{VAULT_ADDR}/v1/identity/oidc/token/service-token",
                               headers={"X-Vault-Token": self.token}, timeout=5)
              r.raise_for_status()
              return r.json()["data"]["token"]

      vault = Vault()

      def call_backend(path, jwt_token):
          # mTLS client context using our SPIRE-issued SVID. SPIFFE certs carry a
          # URI SAN (not a DNS name), so hostname checking is off — identity is
          # verified by the SPIFFE ID, and the bundle validates the server cert.
          ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
          ctx.load_cert_chain("/certs/svid.pem", "/certs/svid_key.pem")
          ctx.load_verify_locations("/certs/svid_bundle.pem")
          ctx.check_hostname = False
          ctx.verify_mode = ssl.CERT_REQUIRED
          req = urllib.request.Request(f"{BACKEND_URL}{path}",
                                       headers={"Authorization": f"Bearer {jwt_token}"})
          with urllib.request.urlopen(req, context=ctx, timeout=5) as resp:
              return resp.status, json.loads(resp.read().decode())

      @app.route("/data")
      def data():
          jwt_token = vault.get_jwt()
          try:
              status, body = call_backend("/data", jwt_token)
          except Exception as e:
              return jsonify({"source": "frontend", "error": str(e)}), 502
          return jsonify({
              "source": "frontend",
              "connection": "mTLS (SPIFFE) + JWT",
              "backend_status": status,
              "backend_response": body,
          })

      @app.route("/healthz")
      def healthz():
          return "ok"

      if __name__ == "__main__":
          app.run(host="0.0.0.0", port=8080)
    PYEOF
  }
}

resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.demo.metadata[0].name
    labels    = { app = "frontend" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "frontend" }
    }
    template {
      metadata {
        labels = { app = "frontend" }
      }
      spec {
        service_account_name = kubernetes_service_account.frontend.metadata[0].name

        init_container {
          name    = "install-deps"
          image   = "python:3.12-slim"
          command = ["pip", "install", "--target=/packages", "flask", "requests"]
          volume_mount {
            name       = "packages"
            mount_path = "/packages"
          }
        }

        container {
          name    = "frontend"
          image   = "python:3.12-slim"
          command = ["/bin/sh", "-c"]
          args = [
            "while [ ! -f /certs/svid.pem ]; do echo waiting for SVID; sleep 2; done; export PYTHONPATH=/packages; python /app/app.py"
          ]

          env {
            name  = "VAULT_ADDR"
            value = var.vault_internal_addr
          }
          # Backend is now mTLS on 8443
          env {
            name  = "BACKEND_URL"
            value = "https://backend.${var.namespace}.svc.cluster.local:8443"
          }

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "code"
            mount_path = "/app"
          }
          volume_mount {
            name       = "packages"
            mount_path = "/packages"
          }
          volume_mount {
            name       = "certs"
            mount_path = "/certs"
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 25
            period_seconds        = 10
          }
        }

        container {
          name  = "spiffe-helper"
          image = var.spiffe_helper_image
          args  = ["-config", "/config/helper.conf"]
          volume_mount {
            name       = "spiffe-workload-api"
            mount_path = "/spiffe-workload-api"
            read_only  = true
          }
          volume_mount {
            name       = "certs"
            mount_path = "/certs"
          }
          volume_mount {
            name       = "helper-config"
            mount_path = "/config"
          }
        }

        volume {
          name = "code"
          config_map {
            name = kubernetes_config_map.frontend_code.metadata[0].name
          }
        }
        volume {
          name = "helper-config"
          config_map {
            name = kubernetes_config_map.frontend_helper.metadata[0].name
          }
        }
        volume {
          name = "packages"
          empty_dir {}
        }
        volume {
          name = "certs"
          empty_dir {}
        }
        volume {
          name = "spiffe-workload-api"
          csi {
            driver    = "csi.spiffe.io"
            read_only = true
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
  spec {
    selector = { app = "frontend" }
    port {
      port        = 8080
      target_port = 8080
    }
  }
}

# --- Attacker (same namespace, but NO SPIFFE identity) ---
#
# The attacker pod does NOT mount the SPIFFE CSI volume, so it has no SVID and
# cannot present a client certificate. Even sitting right next to the backend in
# the same namespace, its mTLS handshake fails — network proximity is not
# identity. (It also has no OpenBao role, so it couldn't get a JWT either.)

resource "kubernetes_service_account" "attacker" {
  metadata {
    name      = "attacker"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
}

resource "kubernetes_deployment" "attacker" {
  metadata {
    name      = "attacker"
    namespace = kubernetes_namespace.demo.metadata[0].name
    labels    = { app = "attacker" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "attacker" }
    }
    template {
      metadata {
        labels = { app = "attacker" }
      }
      spec {
        service_account_name = kubernetes_service_account.attacker.metadata[0].name
        container {
          name    = "attacker"
          image   = "curlimages/curl:latest"
          command = ["sh", "-c", "echo 'attacker ready — no SVID, no identity'; sleep infinity"]
        }
        # Deliberately NO spiffe-workload-api CSI volume.
      }
    }
  }
}
