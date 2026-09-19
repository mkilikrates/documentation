output "canary_kv_path" {
  description = "Full KV path of the honey-token (the read path to alert on)"
  value       = "${var.kv_mount}/data/${var.canary_path}"
}

output "canary_policy_name" {
  description = "Name of the trap policy (attached to no legitimate role)"
  value       = vault_policy.canary_trap.name
}
