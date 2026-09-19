# OpenBao Configuration — Auth methods, policies, audit backends
# This module configures OpenBao after it has been deployed and unsealed.
# Uses the hashicorp/vault provider (API-compatible with OpenBao).

# Note: the audit device is declared in OpenBao's server config (HCL), not via
# the API — API creation of file/socket audit devices is gated behind
# unsafe_allow_api_audit_creation, so the declarative `audit "file"` stanza in
# the openbao-server module's Raft config is the safe way to enable it.

# Enable Kubernetes auth method (backed by SPIFFE)
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"

  description = "Kubernetes auth via SPIFFE/SPIRE workload identity"
}

resource "vault_kubernetes_auth_backend_config" "default" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.kubernetes_host
  disable_iss_validation = true

  lifecycle {
    ignore_changes = [disable_local_ca_jwt, kubernetes_ca_cert]
  }
}

# Base policy: allow token self-management
resource "vault_policy" "base" {
  name   = "base"
  policy = <<-EOT
    # Allow tokens to look up their own properties
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    # Allow tokens to renew themselves
    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

    # Allow tokens to revoke themselves
    path "auth/token/revoke-self" {
      capabilities = ["update"]
    }

    # Allow a token to look up its own capabilities on a path
    path "sys/capabilities-self" {
      capabilities = ["update"]
    }
  EOT
}

# Admin policy — full access (for initial setup only, token should be revoked)
resource "vault_policy" "admin" {
  name   = "admin"
  policy = <<-EOT
    # Full admin access — use only for initial setup
    # Revoke admin tokens after configuration is complete
    path "*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}

# Audit policy — read-only access to audit and system health
resource "vault_policy" "audit_reader" {
  name   = "audit-reader"
  policy = <<-EOT
    # Read system health
    path "sys/health" {
      capabilities = ["read"]
    }

    # List audit devices
    path "sys/audit" {
      capabilities = ["read"]
    }

    # Read metrics
    path "sys/metrics" {
      capabilities = ["read"]
    }

    # List auth methods
    path "sys/auth" {
      capabilities = ["read"]
    }

    # List mounts
    path "sys/mounts" {
      capabilities = ["read"]
    }
  EOT
}

# Enable KV v2 secrets engine for static secrets (migration path)
resource "vault_mount" "kv" {
  count = var.enable_kv_engine ? 1 : 0

  path        = "secret"
  type        = "kv"
  description = "KV v2 — for static secrets during migration to dynamic credentials"

  options = {
    version = "2"
  }

  lifecycle {
    ignore_changes = [seal_wrap, external_entropy_access]
  }
}
