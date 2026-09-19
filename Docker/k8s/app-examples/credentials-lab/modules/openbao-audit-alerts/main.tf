# OpenBao Audit Alerts (Part 5) — Grafana alert rules over the OpenBao audit log
#
# OpenBao's audit device writes one JSON object per line to stdout (see
# modules/openbao-server). Alloy ships those lines to Loki as normal pod logs,
# labelled namespace="openbao-system". These rules query that stream with LogQL
# and fire when credential-usage anomalies appear.
#
# Audit JSON shape (subset we use), flattened by LogQL's `| json` with `_`:
#   type                                -> "request" | "response"
#   request.path        -> request_path
#   request.operation   -> request_operation
#   request.remote_address -> request_remote_address
#   auth.metadata.role  -> auth_metadata_role
#   auth.metadata.service_account_name -> auth_metadata_service_account_name
#
# Requires: a reachable Grafana with a Loki datasource. The unit points the
# grafana provider at GRAFANA_URL/GRAFANA_AUTH and passes the Loki datasource
# UID (the observability module provisions it as uid = "loki").

# Folder to hold the security rules
resource "grafana_folder" "security" {
  title = var.folder_title
}

# A dummy "always OK" threshold reference is not needed: each rule pairs a Loki
# count query (ref A) with a threshold expression (ref C) using the __expr__
# datasource. When A crosses the threshold, the rule fires.

resource "grafana_rule_group" "credential_anomalies" {
  name             = "credential-anomalies"
  folder_uid       = grafana_folder.security.uid
  interval_seconds = var.eval_interval_seconds

  # ---------------------------------------------------------------------------
  # Alert 1: Canary / honey-token read.
  # Any successful read of the canary path is, by design, a leak or a probe.
  # ---------------------------------------------------------------------------
  rule {
    name           = "CanaryCredentialAccessed"
    condition      = "C"
    for            = "0s"
    no_data_state  = "OK"
    exec_err_state = "Error"

    data {
      ref_id         = "A"
      datasource_uid = var.loki_datasource_uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        refId      = "A"
        datasource = { type = "loki", uid = var.loki_datasource_uid }
        expr       = "sum(count_over_time({namespace=\"${var.openbao_namespace}\"} | json | request_path = `${var.canary_path}` [5m]))"
        queryType  = "instant"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "A"
        conditions = [{
          evaluator = { type = "gt", params = [0] }
        }]
      })
    }

    annotations = {
      summary     = "Canary credential accessed"
      description = "The honey-token at ${var.canary_path} was read. No legitimate workload should ever read it. Investigate immediately."
      runbook_url = var.runbook_url
    }
    labels = {
      severity = "critical"
      source   = "openbao-audit"
    }
  }

  # ---------------------------------------------------------------------------
  # Alert 2: Break-glass credential used.
  # Fires whenever the oncall break-glass role fetches migration DB creds.
  # Expected to correlate with an incident; verify one exists.
  # ---------------------------------------------------------------------------
  rule {
    name           = "BreakGlassAccessDetected"
    condition      = "C"
    for            = "0s"
    no_data_state  = "OK"
    exec_err_state = "Error"

    data {
      ref_id         = "A"
      datasource_uid = var.loki_datasource_uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        refId      = "A"
        datasource = { type = "loki", uid = var.loki_datasource_uid }
        expr       = "sum(count_over_time({namespace=\"${var.openbao_namespace}\"} | json | type = `response` | request_path =~ `database/creds/migration.*` [5m]))"
        queryType  = "instant"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "A"
        conditions = [{
          evaluator = { type = "gt", params = [0] }
        }]
      })
    }

    annotations = {
      summary     = "Break-glass access detected"
      description = "A migration (break-glass) database credential was issued. Verify an active incident ticket exists."
      runbook_url = var.runbook_url
    }
    labels = {
      severity = "warning"
      source   = "openbao-audit"
    }
  }

  # ---------------------------------------------------------------------------
  # Alert 3: Credential request burst (possible automated exfiltration).
  # Counts database credential issuances in the last minute across all identities.
  # ---------------------------------------------------------------------------
  rule {
    name           = "CredentialRequestBurst"
    condition      = "C"
    for            = "0s"
    no_data_state  = "OK"
    exec_err_state = "Error"

    data {
      ref_id         = "A"
      datasource_uid = var.loki_datasource_uid
      relative_time_range {
        from = 60
        to   = 0
      }
      model = jsonencode({
        refId      = "A"
        datasource = { type = "loki", uid = var.loki_datasource_uid }
        expr       = "sum(count_over_time({namespace=\"${var.openbao_namespace}\"} | json | type = `response` | request_path =~ `database/creds/.*` [1m]))"
        queryType  = "instant"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 60
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "A"
        conditions = [{
          evaluator = { type = "gt", params = [var.burst_threshold] }
        }]
      })
    }

    annotations = {
      summary     = "Credential request burst detected"
      description = "More than ${var.burst_threshold} database credentials were issued in 1 minute. Possible automated exfiltration."
      runbook_url = var.runbook_url
    }
    labels = {
      severity = "critical"
      source   = "openbao-audit"
    }
  }

  # ---------------------------------------------------------------------------
  # Alert 4: Denied database credential request.
  # A `permission denied` response on database/creds/* means something tried to
  # obtain a credential it isn't entitled to — e.g. a stolen/forged token, or a
  # workload reaching for a tier it shouldn't. This is the STRONGEST signal in a
  # single-cluster lab: unlike source IP (every pod already has a different IP on
  # Kind, so IP is not a reliable discriminator), a denied request unambiguously
  # means an unauthorized attempt. Authorized requests carry auth.metadata
  # (service_account_name, role); denied ones don't and include an error.
  # ---------------------------------------------------------------------------
  rule {
    name           = "UnauthorizedCredentialRequest"
    condition      = "C"
    for            = "0s"
    no_data_state  = "OK"
    exec_err_state = "Error"

    data {
      ref_id         = "A"
      datasource_uid = var.loki_datasource_uid
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        refId      = "A"
        datasource = { type = "loki", uid = var.loki_datasource_uid }
        expr       = "sum(count_over_time({namespace=\"${var.openbao_namespace}\"} |= `permission denied` | json | type = `response` | request_path =~ `database/creds/.*` [5m]))"
        queryType  = "instant"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "A"
        conditions = [{
          evaluator = { type = "gt", params = [0] }
        }]
      })
    }

    annotations = {
      summary     = "Unauthorized database credential request"
      description = "A request for a database/creds/* credential was DENIED (permission denied). Something tried to obtain a credential it isn't entitled to — investigate the source workload/token."
      runbook_url = var.runbook_url
    }
    labels = {
      severity = "critical"
      source   = "openbao-audit"
    }
  }
}
