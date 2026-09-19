output "folder_uid" {
  description = "UID of the Grafana folder holding the security alert rules"
  value       = grafana_folder.security.uid
}

output "rule_group_name" {
  description = "Name of the credential-anomalies alert rule group"
  value       = grafana_rule_group.credential_anomalies.name
}
