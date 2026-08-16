output "gateway_name" {
  description = "Name of the shared gateway"
  value       = "nginx-shared-gateway"
}

output "gateway_namespace" {
  description = "Namespace of the shared gateway"
  value       = kubernetes_namespace.nginx_gateway.metadata[0].name
}

output "private_ip" {
  description = "The private IP used for nip.io hostnames"
  value       = local.private_ip
}

output "nginx_fabric_version" {
  description = "Deployed version of NGINX Gateway Fabric"
  value       = helm_release.nginx_gateway_fabric.version
}
