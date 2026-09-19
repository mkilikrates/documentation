variable "oidc_issuer_url" {
  description = "Keycloak realm issuer URL (used for discovery and bound_issuer). Must match the issuer in Keycloak's tokens."
  type        = string
}

variable "oidc_client_id" {
  description = "OIDC client ID registered in Keycloak for OpenBao (not secret; used for bound_audiences)"
  type        = string
  default     = "openbao"
}

# The OIDC client SECRET is not passed as a variable — it's read from OpenBao KV
# ephemerally (written there by keycloak-config), so it never touches state.
variable "openbao_kv_mount" {
  description = "OpenBao KV v2 mount where the OIDC client secret is stored"
  type        = string
  default     = "secret"
}

variable "openbao_kv_oidc_client_path" {
  description = "OpenBao KV path holding the OpenBao OIDC client credentials"
  type        = string
  default     = "keycloak/openbao-oidc-client"
}

variable "openbao_external_url" {
  description = "External OpenBao URL for the UI OIDC callback redirect"
  type        = string
}
