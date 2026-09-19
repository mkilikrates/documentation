# OpenBao Canary — honey-token credential for leak detection (Part 5)
#
# ============================================================================
# INTENTIONAL EXCEPTION TO THE "NO PLAINTEXT SECRETS" RULE
# ============================================================================
# Everywhere else in this lab, secrets are generated, write-only, and kept out
# of state (see the postgresql / keycloak / gitea modules). This module is the
# ONE deliberate exception, and that is the whole point:
#
#   * The canary is NOT a real credential. It grants access to nothing.
#   * It exists only to be READ. No legitimate workload is ever granted the
#     policy that allows reading it.
#   * Any read of this path is, by definition, someone probing your secrets —
#     an insider or a compromised workload enumerating available paths. The
#     audit log entry for that read is the signal we alert on (see the
#     openbao-audit-alerts module).
#
# Because it is fake and static-by-design, we store it as a plain KV secret. If
# we generated/rotated it like a real secret it would only make the trap harder
# to reason about. The value below is obviously-fake on purpose.
# ============================================================================

# The honey-token KV secret. Placed at a tempting-looking path so that anyone
# listing/enumerating secret paths is drawn to it.
resource "vault_kv_secret_v2" "canary" {
  mount = var.kv_mount
  name  = var.canary_path

  # Plaintext, and that is deliberate — see the header comment. This is not a
  # real credential; it is bait. The `note` field makes intent unmistakable to
  # anyone (including a future maintainer) who reads it.
  data_json = jsonencode({
    username = "canary-admin"
    password = "THIS-IS-A-FAKE-CANARY-CREDENTIAL-DO-NOT-USE"
    host     = "prod-db.internal.example"
    note     = "HONEY TOKEN. If this credential is ever read or used, it is a leak/probe. Investigate immediately."
  })
}

# A policy that grants read on the canary path. It is intentionally attached to
# NO auth role — it exists so the path shows up in capability/path listings and
# looks "real" to an attacker enumerating what they can reach. Legitimate access
# should never happen.
resource "vault_policy" "canary_trap" {
  name   = var.canary_policy_name
  policy = <<-EOT
    # Canary trap. Attached to no legitimate role on purpose.
    # Any successful read here means the trap was tripped — alert and investigate.
    path "${var.kv_mount}/data/${var.canary_path}" {
      capabilities = ["read"]
    }
  EOT
}
