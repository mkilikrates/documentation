# OpenBao database secrets engine — Just-In-Time PostgreSQL credentials.
# Each request creates a unique DB user with a VALID UNTIL expiry; OpenBao
# drops the user when the lease expires.

resource "vault_mount" "database" {
  path                      = "database"
  type                      = "database"
  description               = "Dynamic database credentials"
  default_lease_ttl_seconds = var.default_ttl
  max_lease_ttl_seconds     = var.max_ttl
}

# Read the postgres admin credential from OpenBao ephemerally (the postgresql
# module generated it and stored it there). Never written to state or plan.
ephemeral "vault_kv_secret_v2" "pg_admin" {
  mount = var.openbao_kv_mount
  name  = var.openbao_kv_path
}

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_mount.database.path
  name          = "postgres-app"
  allowed_roles = ["readonly", "readwrite", "migration"]

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@${var.postgres_host}:${var.postgres_port}/${var.postgres_db}?sslmode=disable"
    # username is not secret — use the plain var. (An ephemeral value can only
    # feed ephemeral/write-only attributes, and `username` is neither.)
    username = var.postgres_admin_user

    # Write-only connection password — read from OpenBao, not stored in state.
    password_wo         = ephemeral.vault_kv_secret_v2.pg_admin.data["password"]
    password_wo_version = 1
  }

  verify_connection = true
}

# --- Roles ---

resource "vault_database_secret_backend_role" "readonly" {
  backend     = vault_mount.database.path
  name        = "readonly"
  db_name     = vault_database_secret_backend_connection.postgres.name
  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO \"{{name}}\";"
  ]

  # A plain DROP ROLE fails (SQLSTATE 2BP01) if the role owns objects or holds
  # grants. REASSIGN OWNED hands any owned objects to the admin role, DROP OWNED
  # clears remaining objects + privileges + default-privilege ACL entries, then
  # DROP ROLE succeeds. For readonly, REASSIGN is a no-op but keeps all roles uniform.
  revocation_statements = [
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = '{{name}}';",
    "REASSIGN OWNED BY \"{{name}}\" TO \"${var.postgres_admin_user}\";",
    "DROP OWNED BY \"{{name}}\";",
    "DROP ROLE IF EXISTS \"{{name}}\";"
  ]

  renew_statements = [
    "ALTER ROLE \"{{name}}\" VALID UNTIL '{{expiration}}';"
  ]
}

resource "vault_database_secret_backend_role" "readwrite" {
  backend     = vault_mount.database.path
  name        = "readwrite"
  db_name     = vault_database_secret_backend_connection.postgres.name
  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
    "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";",
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"{{name}}\";",
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO \"{{name}}\";"
  ]

  # Reassign objects this user created back to admin, drop remaining objects +
  # privileges, then drop the role. Prevents SQLSTATE 2BP01 on revocation.
  revocation_statements = [
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = '{{name}}';",
    "REASSIGN OWNED BY \"{{name}}\" TO \"${var.postgres_admin_user}\";",
    "DROP OWNED BY \"{{name}}\";",
    "DROP ROLE IF EXISTS \"{{name}}\";"
  ]

  renew_statements = [
    "ALTER ROLE \"{{name}}\" VALID UNTIL '{{expiration}}';"
  ]
}

resource "vault_database_secret_backend_role" "migration" {
  backend     = vault_mount.database.path
  name        = "migration"
  db_name     = vault_database_secret_backend_connection.postgres.name
  default_ttl = 300  # 5 minutes — migrations should be fast
  max_ttl     = 600  # 10 minutes absolute max

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT ALL PRIVILEGES ON SCHEMA public TO \"{{name}}\";",
    "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
    "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";"
  ]

  # A migration user runs DDL, so it OWNS tables/sequences. REASSIGN OWNED hands
  # them to admin (preserving the schema changes — dropping them would undo the
  # migration), DROP OWNED clears the rest, then DROP ROLE succeeds. Prevents 2BP01.
  revocation_statements = [
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = '{{name}}';",
    "REASSIGN OWNED BY \"{{name}}\" TO \"${var.postgres_admin_user}\";",
    "DROP OWNED BY \"{{name}}\";",
    "DROP ROLE IF EXISTS \"{{name}}\";"
  ]
}

# --- Policies ---

resource "vault_policy" "db_readonly" {
  name   = "db-readonly"
  policy = <<-EOT
    path "database/creds/readonly" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "db_readwrite" {
  name   = "db-readwrite"
  policy = <<-EOT
    path "database/creds/readwrite" {
      capabilities = ["read"]
    }
    path "database/creds/readonly" {
      capabilities = ["read"]
    }
  EOT
}

# Migration access (used by the CI/CD pipeline from Part 2). The migration DB
# role is high-privilege/short-TTL; this policy grants read access to it so a
# pipeline token with pipeline-deploy can fetch a DDL-capable credential.
resource "vault_policy" "db_migration" {
  name   = "db-migration"
  policy = <<-EOT
    path "database/creds/migration" {
      capabilities = ["read"]
    }
  EOT
}

# --- Kubernetes auth roles that map the demo app SAs to DB policies ---

# Three workloads, three identities, three least-privilege DB roles:
#   - api-reader  (Deployment, GET /items)  -> api-readonly  -> db-readonly
#   - api-writer  (Deployment, POST /items) -> api-readwrite -> db-readwrite
#   - api-migrator (Job, runs once)         -> api-migrate   -> db-migration
# Each OpenBao role is bound to its OWN service account, so an identity can only
# ever obtain the credential tier it needs. The reader can't write; only the
# short-lived migration Job can run DDL.

resource "vault_kubernetes_auth_backend_role" "api_readwrite" {
  backend                          = var.kubernetes_auth_path
  role_name                        = "api-readwrite"
  bound_service_account_names      = ["api-writer"]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = ["base", "db-readwrite"]
  token_ttl                        = 3600
}

resource "vault_kubernetes_auth_backend_role" "api_readonly" {
  backend                          = var.kubernetes_auth_path
  role_name                        = "api-readonly"
  bound_service_account_names      = ["api-reader"]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = ["base", "db-readonly"]
  token_ttl                        = 3600
}

# Migration role for the one-shot schema Job: short-TTL, DDL-capable JIT creds
# used once to create/seed the schema, then discarded. No long-running workload
# holds this.
resource "vault_kubernetes_auth_backend_role" "api_migrate" {
  backend                          = var.kubernetes_auth_path
  role_name                        = "api-migrate"
  bound_service_account_names      = ["api-migrator"]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = ["base", "db-migration"]
  token_ttl                        = 600
}
