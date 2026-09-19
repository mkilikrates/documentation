# The keycloak provider authenticates one of two ways, both reading their
# credentials from OpenBao EPHEMERALLY (never persisted to state):
#
#   - bootstrap  (default, first apply): the temporary bootstrap admin
#                 (username/password) created by the keycloak module. Used to
#                 create the realm and the permanent terraform-admin service
#                 account.
#   - service_account (after hardening): the terraform-admin client-credentials
#                 grant. Use this once the bootstrap admin has been removed
#                 (see harden-remove-bootstrap-admin.sh). Set
#                 keycloak_auth_mode = "service_account".
#
# Both credential sources live in OpenBao; nothing sensitive is a Terraform
# variable or stored in state.

ephemeral "vault_kv_secret_v2" "kc_bootstrap" {
  mount = var.openbao_kv_mount
  name  = var.openbao_kv_bootstrap_path
}

# The service-account secret only exists after the first apply created it.
# Reading it is gated on the auth mode so the first (bootstrap) apply doesn't
# fail trying to read a not-yet-existing path.
ephemeral "vault_kv_secret_v2" "kc_sa" {
  count = var.keycloak_auth_mode == "service_account" ? 1 : 0
  mount = var.openbao_kv_mount
  name  = var.openbao_kv_tf_admin_path
}

provider "keycloak" {
  url = var.keycloak_url

  # Bootstrap (password) auth — default / first apply
  client_id = var.keycloak_auth_mode == "service_account" ? var.tf_admin_client_id : "admin-cli"
  username  = var.keycloak_auth_mode == "service_account" ? null : ephemeral.vault_kv_secret_v2.kc_bootstrap.data["username"]
  password  = var.keycloak_auth_mode == "service_account" ? null : ephemeral.vault_kv_secret_v2.kc_bootstrap.data["password"]

  # Service-account (client credentials) auth — after hardening
  client_secret = var.keycloak_auth_mode == "service_account" ? ephemeral.vault_kv_secret_v2.kc_sa[0].data["client_secret"] : null
}
