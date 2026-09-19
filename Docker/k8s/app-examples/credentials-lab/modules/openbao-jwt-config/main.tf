# OpenBao JWT/Identity Token Configuration
# Configures identity tokens for service-to-service auth
# and JWT auth method for CI/CD pipeline credentials (Gitea OIDC)

# --- Service-to-Service: Identity Tokens ---

# Signing key for service tokens
resource "vault_identity_oidc_key" "service_key" {
  name               = "service-key"
  algorithm          = "RS256"
  rotation_period    = 86400   # Rotate signing key every 24h
  verification_ttl   = 172800  # Old keys remain valid for verification for 48h
  allowed_client_ids = ["*"]
}

# Look up the Kubernetes auth mount so we can reference alias metadata.
# When a pod logs in via Kubernetes auth, the service_account_name and
# service_account_namespace live on the entity *alias*, keyed by the mount
# accessor — not directly on the entity.
data "vault_auth_backend" "kubernetes" {
  path = var.kubernetes_auth_path
}

# Role that defines the JWT claims template
resource "vault_identity_oidc_role" "service_token" {
  name = "service-token"
  key  = vault_identity_oidc_key.service_key.name
  ttl  = 900 # 15-minute token lifetime

  # Pin the audience. Every OIDC role has a client_id that OpenBao writes into
  # the token's `aud` claim; unset, it's an opaque random value. Setting it
  # explicitly gives the backend a stable audience to verify against, so a token
  # minted for backend-api can't be replayed against a different service.
  client_id = "backend-api"

  # Vault/OpenBao automatically quotes metadata string values, so the
  # placeholders must NOT be wrapped in quotes in the template JSON.
  # Note: "namespace" is a reserved OIDC claim, so we use "k8s_namespace".
  # Metadata is read from the entity alias (keyed by the k8s auth accessor).
  template = "{\"k8s_namespace\": {{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}, \"service\": {{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_name}}}"
}

# Policy allowing a service to request identity tokens
resource "vault_policy" "token_issuer" {
  name   = "token-issuer"
  policy = <<-EOT
    # Allow reading the OIDC token for the service-token role
    path "identity/oidc/token/service-token" {
      capabilities = ["read"]
    }

    # Allow introspection (for debugging)
    path "identity/oidc/introspect" {
      capabilities = ["update"]
    }
  EOT
}

# --- Kubernetes Auth Roles for Demo Services ---

# Frontend service — can request JWTs (token-issuer policy)
resource "vault_kubernetes_auth_backend_role" "frontend" {
  backend                          = var.kubernetes_auth_path
  role_name                        = "frontend"
  bound_service_account_names      = ["frontend"]
  bound_service_account_namespaces = ["credentials-demo"]
  token_policies                   = ["base", "token-issuer"]
  token_ttl                        = 3600
}

# Backend service — validates JWTs, doesn't issue them
resource "vault_kubernetes_auth_backend_role" "backend" {
  backend                          = var.kubernetes_auth_path
  role_name                        = "backend"
  bound_service_account_names      = ["backend"]
  bound_service_account_namespaces = ["credentials-demo"]
  token_policies                   = ["base"]
  token_ttl                        = 3600
}

# --- CI/CD Pipeline: JWT Auth for Gitea Actions ---

# Readiness gate: OpenBao validates the OIDC discovery URL live when the
# jwt-gitea backend is created. A Terraform `dependency` only orders the units;
# it does NOT guarantee Gitea is actually SERVING its discovery document yet.
# So we poll the discovery URL with exponential backoff before creating the
# backend. Two outcomes:
#   * Gitea comes up in time  -> the poll returns 200 and the backend is created.
#   * Gitea never serves it   -> the poll times out with a clear message, instead
#     of OpenBao half-creating the mount (which then causes "path is already in
#     use" on the next run). This makes the failure honest and leaves no orphan.
resource "null_resource" "gitea_discovery_ready" {
  count = var.enable_gitea_jwt ? 1 : 0

  # Re-check whenever the discovery URL changes. gitea_oidc_url has NO trailing
  # slash (it must equal the advertised issuer), so add one before the path.
  triggers = {
    discovery_url = "${var.gitea_oidc_url}/.well-known/openid-configuration"
  }

  # Poll the EXTERNAL discovery URL (the same URL OpenBao validates against, and
  # which we confirmed OpenBao reaches from in-cluster). Exponential backoff, but
  # keep retrying until a hard TOTAL time budget elapses (default 5 minutes) —
  # Gitea can be slow to come up. We also require the doc's "issuer" to equal
  # gitea_oidc_url exactly (the trailing-slash/host match OpenBao enforces), so a
  # 200 with the wrong issuer doesn't count as ready. Once ready, wait an extra
  # settle period (default 30s) before letting the backend be created.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      URL           = "${var.gitea_oidc_url}/.well-known/openid-configuration"
      WANT_ISSUER   = var.gitea_oidc_url
      MAX_WAIT_SECS = tostring(var.gitea_discovery_max_wait_seconds)
      SETTLE_SECS   = tostring(var.gitea_discovery_settle_seconds)
    }
    command = <<-EOT
      start=$(date +%s)
      attempt=1
      delay=5
      while :; do
        body=$(curl -s --max-time 10 "$URL" 2>/dev/null || true)
        iss=$(printf '%s' "$body" | sed -n 's/.*"issuer"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
        if [ "$iss" = "$WANT_ISSUER" ]; then
          echo "Gitea OIDC discovery ready and issuer matches ($iss) after $attempt attempt(s)."
          echo "Waiting $${SETTLE_SECS}s for Gitea to settle before configuring OpenBao..."
          sleep "$SETTLE_SECS"
          exit 0
        fi

        elapsed=$(( $(date +%s) - start ))
        if [ "$elapsed" -ge "$MAX_WAIT_SECS" ]; then
          echo "ERROR: Gitea OIDC discovery not ready at $URL with issuer '$WANT_ISSUER' after $${MAX_WAIT_SECS}s." >&2
          echo "       If the issuer differs, align gitea_oidc_url with Gitea's ROOT_URL (no trailing slash)." >&2
          echo "       If it's never reachable, confirm Gitea is up and the gateway route works, or set" >&2
          echo "       enable_gitea_jwt = false and treat the pipeline as illustrative." >&2
          exit 1
        fi

        if [ -n "$iss" ]; then
          echo "Attempt $attempt ($${elapsed}s/$${MAX_WAIT_SECS}s): reachable but issuer '$iss' != '$WANT_ISSUER'; retry in $${delay}s..."
        else
          echo "Attempt $attempt ($${elapsed}s/$${MAX_WAIT_SECS}s): $URL not ready; retry in $${delay}s..."
        fi
        sleep "$delay"
        attempt=$((attempt + 1))
        delay=$((delay * 2)); [ "$delay" -gt 60 ] && delay=60   # cap backoff step at 60s
      done
    EOT
  }
}

# JWT auth method for Gitea OIDC tokens
resource "vault_jwt_auth_backend" "gitea" {
  count = var.enable_gitea_jwt ? 1 : 0

  path               = "jwt-gitea"
  type               = "jwt"
  description        = "Gitea Actions OIDC authentication"
  oidc_discovery_url = var.gitea_oidc_url
  bound_issuer       = var.gitea_oidc_url
  default_role       = "gitea-pipeline"

  # Only attempt creation once Gitea is actually serving discovery.
  depends_on = [null_resource.gitea_discovery_ready]
}

# Role for pipeline authentication
resource "vault_jwt_auth_backend_role" "pipeline" {
  count = var.enable_gitea_jwt ? 1 : 0

  backend   = vault_jwt_auth_backend.gitea[0].path
  role_name = "gitea-pipeline"
  role_type = "jwt"

  bound_audiences = ["openbao"]

  claim_mappings = {
    repository = "repository"
    ref        = "ref"
    actor      = "actor"
  }

  token_policies = ["base", "pipeline-deploy"]
  token_ttl      = 600   # 10 minutes
  token_max_ttl  = 1800  # 30 minutes max

  user_claim = "sub"
}

# Policy for CI/CD pipeline deployments
resource "vault_policy" "pipeline_deploy" {
  name   = "pipeline-deploy"
  policy = <<-EOT
    # Read registry credentials for image push
    path "secret/data/registry/*" {
      capabilities = ["read"]
    }

    # Sign images using transit engine
    path "transit/sign/cosign-key/*" {
      capabilities = ["update"]
    }

    # Read deploy credentials
    path "secret/data/deploy/*" {
      capabilities = ["read"]
    }
  EOT
}
