output "private_ip" {
  description = "The private IP used for nip.io hostnames"
  value       = local.private_ip
}

output "gateway_name" {
  description = "Name of the shared gateway"
  value       = "nginx-shared-gateway"
}

output "gateway_namespace" {
  description = "Namespace of the shared gateway"
  value       = "nginx-gateway"
}
