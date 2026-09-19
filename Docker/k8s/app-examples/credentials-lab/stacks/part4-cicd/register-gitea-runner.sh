#!/usr/bin/env bash
#
# Part 2 (CI/CD): register the Gitea Actions runner.
#
# The gitea-runner module deploys act_runner + a placeholder registration-token
# Secret. A runner registration token is minted BY Gitea and isn't a value
# Terraform can know ahead of time, so we generate it here at runtime with
# Gitea's own CLI (via kubectl exec) and write it into the Secret the runner
# reads. Using the CLI (rather than the HTTP admin API) keeps this robust across
# Gitea versions and needs no admin credentials.
#
# Prerequisites:
#   - stacks/part2 applied and Gitea Running
#   - stacks/part4-cicd applied (runner Deployment + placeholder token Secret)
#   - kubectl context on the lab cluster
#
# Usage:
#   ./register-gitea-runner.sh

set -euo pipefail

# The token is minted via the Gitea CLI (kubectl exec), so no VAULT_* or
# MY_PRIVATE_IP is needed here — just a kubectl context on the lab cluster.

NAMESPACE="gitea"
TOKEN_SECRET="gitea-runner-token"
RUNNER_DEPLOY="gitea-runner"

# Mint the token with Gitea's own CLI inside the pod. This is version-robust —
# it doesn't depend on the HTTP admin API path (which varies across Gitea
# versions), and it's the same kubectl-exec approach configure-gitea-oidc.sh
# uses. No admin credentials are needed: the CLI runs on the server as the git
# user against the local instance.
gitea_cli() {
  kubectl -n "$NAMESPACE" exec deploy/gitea -c gitea -- gitea "$@"
}

echo "==> Generating an instance-level runner registration token (via Gitea CLI)"
# Gitea prints just the token on stdout. Try the current subcommand, then the
# older location, so this works across versions.
REG_TOKEN="$(gitea_cli actions generate-runner-token 2>/dev/null | tr -d '[:space:]' || true)"
if [ -z "$REG_TOKEN" ]; then
  REG_TOKEN="$(gitea_cli actions generate-runner-token -s 2>/dev/null | tr -d '[:space:]' || true)"
fi

if [ -z "$REG_TOKEN" ]; then
  echo "ERROR: could not generate a runner registration token via the Gitea CLI." >&2
  echo "       Check the available command:" >&2
  echo "         kubectl -n ${NAMESPACE} exec deploy/gitea -c gitea -- gitea actions --help" >&2
  echo "       On some builds the token is under the UI at" >&2
  echo "       http://gitea.<ip>.nip.io/-/admin/actions/runners (copy it and set it" >&2
  echo "       manually: kubectl -n ${NAMESPACE} patch secret ${TOKEN_SECRET} \\" >&2
  echo "         --type merge -p '{\"stringData\":{\"token\":\"<TOKEN>\"}}')." >&2
  exit 1
fi
echo "    got a registration token (length ${#REG_TOKEN})."

echo "==> Writing the token into the ${NAMESPACE}/${TOKEN_SECRET} Secret"
kubectl -n "$NAMESPACE" patch secret "$TOKEN_SECRET" \
  --type merge \
  -p "{\"stringData\":{\"token\":\"${REG_TOKEN}\"}}"

echo "==> Restarting the runner so it registers with the new token"
kubectl -n "$NAMESPACE" rollout restart deploy/"$RUNNER_DEPLOY"
kubectl -n "$NAMESPACE" rollout status deploy/"$RUNNER_DEPLOY" --timeout=180s

echo "==> Done. Verify the runner shows up under Gitea → Admin → Actions → Runners,"
echo "    or check its logs:"
echo "    kubectl -n ${NAMESPACE} logs deploy/${RUNNER_DEPLOY} -c runner"
