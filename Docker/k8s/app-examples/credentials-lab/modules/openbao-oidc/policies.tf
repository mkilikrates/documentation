# Human access policies for the OIDC roles.

# Developers: read-only database access + read non-sensitive config.
resource "vault_policy" "human_db_readonly" {
  name   = "human-db-readonly"
  policy = <<-EOT
    path "database/creds/readonly" {
      capabilities = ["read"]
    }

    # See which roles exist
    path "database/roles" {
      capabilities = ["list"]
    }

    # Read non-sensitive config from KV
    path "secret/data/config/*" {
      capabilities = ["read"]
    }
  EOT
}

# Platform engineers: read-write (and read-only) database access + lease cleanup.
resource "vault_policy" "human_db_readwrite" {
  name   = "human-db-readwrite"
  policy = <<-EOT
    path "database/creds/readwrite" {
      capabilities = ["read"]
    }

    path "database/creds/readonly" {
      capabilities = ["read"]
    }

    path "database/roles" {
      capabilities = ["list"]
    }

    # Revoke own leases after debugging
    path "sys/leases/revoke" {
      capabilities = ["update"]
    }
  EOT
}

# Break-glass: migration-level (DDL) database access, for emergencies only.
resource "vault_policy" "human_db_migration" {
  name   = "human-db-migration"
  policy = <<-EOT
    path "database/creds/migration" {
      capabilities = ["read"]
    }

    path "sys/leases/lookup/*" {
      capabilities = ["list"]
    }

    path "sys/leases/revoke" {
      capabilities = ["update"]
    }
  EOT
}

# Break-glass audit: lets the on-call user record a justification in KV.
#
# IMPORTANT: this policy GRANTS the ability to write a justification; it does
# not TECHNICALLY force one before reading migration creds (OpenBao policies
# cannot make one path a precondition of another). The justification is an
# audited convention — every write is logged, and the break-glass alert fires
# on the migration read regardless. If you need hard enforcement, gate it with
# an external approval workflow or Sentinel/OPA, not a policy path.
resource "vault_policy" "breakglass_audit" {
  name   = "breakglass-audit"
  policy = <<-EOT
    # Write a break-glass justification (recorded in the audit log)
    path "secret/data/breakglass/justification/*" {
      capabilities = ["create", "update"]
    }

    # Read own break-glass history
    path "secret/data/breakglass/justification/*" {
      capabilities = ["read", "list"]
    }
  EOT
}
