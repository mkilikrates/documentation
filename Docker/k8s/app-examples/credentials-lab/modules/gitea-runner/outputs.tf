output "namespace" {
  description = "Namespace the runner runs in"
  value       = var.namespace
}

output "token_secret_name" {
  description = "K8s Secret that register-gitea-runner.sh populates with the registration token"
  value       = kubernetes_secret_v1.runner_token.metadata[0].name
}

output "deployment_name" {
  description = "Runner deployment name (restart it after populating the token)"
  value       = kubernetes_deployment.runner.metadata[0].name
}
