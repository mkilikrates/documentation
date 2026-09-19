output "realm" {
  description = "Realm name"
  value       = keycloak_realm.lab.realm
}

output "issuer_url" {
  description = "OIDC issuer URL for this realm (used by OpenBao oidc_discovery_url / bound_issuer)"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.lab.realm}"
}

output "oidc_client_id" {
  description = "OIDC client ID for OpenBao"
  value       = keycloak_openid_client.openbao.client_id
}
