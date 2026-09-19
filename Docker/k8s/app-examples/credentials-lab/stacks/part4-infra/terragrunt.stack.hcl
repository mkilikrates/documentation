locals {
  name   = "credentials-lab"
  domain = "${get_env("MY_PRIVATE_IP", "127.0.0.1")}.nip.io"
}

# Part 4 (infra): Keycloak (OIDC Identity Provider) deployment.
#
# Split from part4-config for the same reason as Parts 1 and 3: the config
# stack (keycloak realm + OpenBao OIDC) needs Keycloak to be UP and SERVING
# before it can configure the realm and before OpenBao can validate the OIDC
# discovery URL. Deploy this, wait for Keycloak to be Ready, then apply
# part4-config.
#
# Prerequisites:
#   - stacks/part1-infra applied (cluster + nginx-gateway + spire + openbao)
#
# Usage:
#   export MY_PRIVATE_IP="$(ip addr show $(route | grep '^default' | grep -o '[^ ]*$') | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
#   cd stacks/part4-infra
#   terragrunt stack run apply
#   kubectl -n keycloak rollout status statefulset/keycloak

unit "keycloak" {
  source                  = "../../units/keycloak"
  path                    = "keycloak"
  no_dot_terragrunt_stack = false
  values = {
    namespace        = "keycloak"
    admin_user       = "bootstrap-admin"
    expose_gateway   = true
    gateway_domain   = local.domain
    openbao_kv_mount = "secret"
    openbao_kv_path  = "keycloak/bootstrap-admin"
  }
}
