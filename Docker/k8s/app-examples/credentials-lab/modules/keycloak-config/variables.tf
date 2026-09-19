variable "keycloak_url" {
  description = "Keycloak base URL for the admin API (the external gateway URL, so it matches the token issuer)"
  type        = string
}

variable "keycloak_auth_mode" {
  description = "How the keycloak provider authenticates: 'bootstrap' (temporary admin, first apply) or 'service_account' (terraform-admin client credentials, after hardening)"
  type        = string
  default     = "bootstrap"

  validation {
    condition     = contains(["bootstrap", "service_account"], var.keycloak_auth_mode)
    error_message = "keycloak_auth_mode must be 'bootstrap' or 'service_account'."
  }
}

# --- OpenBao KV locations (secrets live here, not in variables/state) ---

variable "openbao_kv_mount" {
  description = "OpenBao KV v2 mount where credentials are stored"
  type        = string
  default     = "secret"
}

variable "openbao_kv_bootstrap_path" {
  description = "OpenBao KV path holding the Keycloak bootstrap admin credential (written by the keycloak module)"
  type        = string
  default     = "keycloak/bootstrap-admin"
}

variable "openbao_kv_oidc_client_path" {
  description = "OpenBao KV path to store the OpenBao OIDC client credentials"
  type        = string
  default     = "keycloak/openbao-oidc-client"
}

variable "openbao_kv_tf_admin_path" {
  description = "OpenBao KV path to store the Terraform admin service-account credentials"
  type        = string
  default     = "keycloak/terraform-admin"
}

variable "openbao_kv_gitea_client_path" {
  description = "OpenBao KV path to store the Gitea OIDC client credentials"
  type        = string
  default     = "keycloak/gitea-oidc-client"
}

variable "realm_name" {
  description = "Realm to create for the lab"
  type        = string
  default     = "credentials-lab"
}

variable "oidc_client_id" {
  description = "OIDC client ID for OpenBao"
  type        = string
  default     = "openbao"
}

variable "tf_admin_client_id" {
  description = "Client ID for the permanent Terraform admin service account"
  type        = string
  default     = "terraform-admin"
}

variable "openbao_external_url" {
  description = "External OpenBao URL, for the UI OIDC callback redirect"
  type        = string
}

variable "gitea_client_id" {
  description = "OIDC client ID for Gitea human SSO login"
  type        = string
  default     = "gitea"
}

variable "gitea_external_url" {
  description = "External Gitea URL, for the OAuth2 login-source callback redirect (http://gitea.<domain>)"
  type        = string
}

# NOTE: demo user passwords are intentionally NOT variables. Users are created
# without a password (see main.tf) and a temporary one is set out-of-band by
# set-demo-user-passwords.sh, so no human credential is stored in state.

variable "demo_users" {
  description = "Usernames of the demo human accounts (passwords set out-of-band, stored in OpenBao)"
  type        = list(string)
  default     = ["engineer", "developer"]
}
