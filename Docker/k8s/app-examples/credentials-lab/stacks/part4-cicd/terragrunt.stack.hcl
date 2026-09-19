locals {
  name = "credentials-lab"
}

# Gitea Actions runner — deploy this as part of the PART 4 walkthrough.
#
# Why part4-cicd (not part2): the CI/CD *building blocks* are prepared in Part 2
# — Gitea (Actions enabled) and the OpenBao jwt-gitea auth method + gitea-pipeline
# role are created by the base part2 stack. But the point
# of running a pipeline is to do it as a HUMAN who logged in via SSO, and SSO
# (Keycloak → Gitea) doesn't exist until Part 4. So the runner is deployed and
# exercised at the end of Part 4, tying SSO identity + runner + jwt-gitea together.
#
# Nothing RUNS jobs until a runner registers. This stack adds that runner; then
# mint a registration token and hand it over (admin creds from OpenBao — no
# static secret):
#   ./register-gitea-runner.sh
#
# Prerequisites:
#   - stacks/part2 applied (Gitea Running; jwt-gitea configured)
#   - stacks/part4-* applied and Keycloak→Gitea SSO configured (configure-gitea-oidc.sh)
#   - VAULT_ADDR / VAULT_TOKEN set; MY_PRIVATE_IP set
#
# Usage (from the Part 4 walkthrough):
#   export MY_PRIVATE_IP="$(ip addr show $(route | grep '^default' | grep -o '[^ ]*$') | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
#   export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
#   export VAULT_TOKEN="<token>"
#   cd stacks/part4-cicd
#   terragrunt stack run apply
#   ./register-gitea-runner.sh
#
# Then (as your SSO user) create a repo with a .gitea/workflows/*.yaml and watch
# the run in the Gitea UI (Actions tab). Full walkthrough: end of Part 4.

unit "gitea-runner" {
  source                  = "../../units/gitea-runner"
  path                    = "gitea-runner"
  no_dot_terragrunt_stack = false
  values = {
    namespace          = "gitea"
    gitea_internal_url = "http://gitea-http.gitea.svc.cluster.local:3000"
    token_secret_name  = "gitea-runner-token"
    runner_capacity    = 1
    default_job_image  = "node:20-bookworm"
  }
}
