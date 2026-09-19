# Credentials Management Lab

Companion code for the [Credentials Management: From Static Secrets to Zero Standing Access](https://github.com/mkilikrates/documentation/tree/main/Docker/k8s/app-examples/credentials-lab) article series.

Everything is deployed with OpenTofu/Terragrunt. **No static secrets**: every password, client secret, and token is either generated at apply time (ephemeral) and written to its consumer via a write-only argument, or issued dynamically by OpenBao — so nothing sensitive is persisted in Terraform state. Durable secrets live in OpenBao, not in git or state.

## Requirements

- Docker running; `kubectl`, `helm`, `tofu`, `terragrunt` installed; Linux or WSL2.
- **OpenTofu 1.11+** and the **`hashicorp/vault` provider v5+** — the lab relies on ephemeral resources and write-only arguments to keep secrets out of state (pinned in `root.hcl`).
- A **Terragrunt** version compatible with your OpenTofu — see the [Terragrunt version compatibility table](https://docs.terragrunt.com/reference/supported-versions/). OpenTofu 1.11.x needs Terragrunt ≥ 0.95.0; 1.12.x needs ≥ 1.0.5.

## Structure

```
credentials-lab/
├── root.hcl                    # Terragrunt root config (local backend; pins TF >=1.11, vault ~>5)
├── common_vars.yaml            # Shared variables
├── env.yaml                    # Environment configuration
├── cluster-config.yaml         # Kind cluster configuration
├── modules/                    # Reusable OpenTofu modules
│   ├── nginx-gateway/          # NGINX Gateway Fabric (shared Gateway API)
│   ├── spire/                  # SPIFFE/SPIRE + cert-manager (workload identity)
│   ├── openbao-server/         # OpenBao Helm deployment (HA, Raft, declarative audit)
│   ├── openbao-config/         # Kubernetes auth method, base/admin policies, KV v2
│   ├── openbao-jwt-config/     # Identity (OIDC) tokens for service-to-service; Gitea JWT auth
│   ├── openbao-database/       # Database secrets engine (Postgres) + roles + policies
│   ├── openbao-oidc/           # OIDC auth method for humans (Keycloak) + human policies
│   ├── postgresql/             # PostgreSQL (generated admin password → OpenBao)
│   ├── gitea/                  # Gitea + Actions (admin via existingSecret → OpenBao)
│   ├── keycloak/               # Keycloak IdP (official upstream manifests, generated admin)
│   ├── keycloak-config/        # Realm, OIDC client, groups, users, service account
│   ├── demo-app-s2s/           # Part 2 demo: frontend/backend over mTLS (SPIFFE) + JWT
│   ├── gitea-runner/           # Part 2 (CI/CD): act_runner Actions runner for Gitea
│   ├── demo-app-db/            # Part 3 demo: migration Job + reader/writer apps (JIT DB creds)
│   ├── observability/          # Part 5: Loki + Alloy + Grafana (leak-detection logging)
│   ├── openbao-canary/         # Part 5: honey-token + trap policy (deliberately fake)
│   └── openbao-audit-alerts/   # Part 5: Grafana alert rules over the audit log in Loki
├── units/                      # Terragrunt units (thin wrappers, one per module)
└── stacks/                     # Terragrunt stacks (per article phase)
    ├── part1-infra/            # nginx-gateway + spire + openbao-server
    ├── part1-config/           # openbao-config (Kubernetes auth, policies, KV)
    ├── part2/                  # gitea + openbao-jwt-config (jwt-gitea) + demo-app-s2s (mTLS)
    ├── part3-infra/            # postgresql
    ├── part3-config/           # openbao-database + demo-app-db
    ├── part4-infra/            # keycloak
    ├── part4-config/           # keycloak-config + openbao-oidc (+ hardening + gitea SSO scripts)
    ├── part4-cicd/             # gitea-runner + register-gitea-runner.sh (deployed in Part 4 walkthrough)
    ├── part5-infra/            # observability (Loki + Alloy + Grafana)
    └── part5-config/           # openbao-canary + openbao-audit-alerts
```

The Kind cluster is created from `cluster-config.yaml` (not a Terragrunt unit).

## Quick Start (Part 1)

Part 1 is split into two stacks because of the Secret Zero problem — you can't configure OpenBao until it's initialized and unsealed.

```bash
export MY_PRIVATE_IP="$(ip addr show $(route | grep '^default' | grep -o '[^ ]*$') | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"

# Phase 1: Deploy infrastructure (NGINX Gateway + SPIRE + OpenBao server).
# The openbao-server unit starts with replicas = 1 on purpose, so openbao-0
# bootstraps as leader without a Raft join race (see openbao/openbao#2274).
cd stacks/part1-infra
terragrunt stack run apply

# Phase 2: Initialize and unseal OpenBao (manual — Secret Zero)
kubectl -n openbao-system exec openbao-0 -- bao operator init \
  -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
UNSEAL_KEY=$(jq -r ".unseal_keys_b64[0]" cluster-keys.json)
kubectl -n openbao-system exec openbao-0 -- bao operator unseal $UNSEAL_KEY

# Phase 2b: Now that openbao-0 is the leader, scale to HA. Set openbao_replicas = 3
# in the part1-infra stack (stacks/part1-infra/terragrunt.stack.hcl locals block),
# re-apply, then unseal the joiners (they retry_join automatically — no manual
# `raft join` needed).
terragrunt stack run apply
kubectl -n openbao-system rollout status statefulset/openbao
kubectl -n openbao-system exec openbao-1 -- bao operator unseal $UNSEAL_KEY
kubectl -n openbao-system exec openbao-2 -- bao operator unseal $UNSEAL_KEY

# Phase 3: Configure OpenBao (via the gateway — no port-forward needed)
export VAULT_ADDR="http://openbao.${MY_PRIVATE_IP}.nip.io"
export VAULT_TOKEN=$(jq -r ".root_token" cluster-keys.json)
cd ../part1-config
terragrunt stack run apply
```

Part 1 deploys: the Kind cluster, NGINX Gateway Fabric, SPIFFE/SPIRE (+ cert-manager), OpenBao in HA mode with Raft (bootstrapped as 1 replica, then scaled to 3) and a declarative file **audit device** (to stdout → Loki), and the OpenBao configuration (Kubernetes auth, base/admin policies, KV v2).

## Deploying the other parts

All later stacks need `VAULT_ADDR`/`VAULT_TOKEN` exported and OpenBao unsealed. **Note:** because passwords are generated and stored in OpenBao, `part3-infra` (PostgreSQL) now also needs a token — a change from earlier revisions where infra had no OpenBao dependency.

```bash
# Part 2 — Gitea + service-to-service mTLS demo. Also prepares the CI/CD OIDC
# trust: the openbao-jwt-config unit (which depends on the gitea unit, so it
# applies after Gitea is up) enables the jwt-gitea auth method + gitea-pipeline
# role. The Actions runner and the actual pipeline run come later, in Part 4.
cd stacks/part2 && terragrunt stack run apply

# Part 3 — PostgreSQL, then the database engine + demo apps. part3-config runs a
# one-shot migration Job (DDL creds) that creates/seeds the schema, then deploys
# the reader (GET, readonly creds) and writer (POST, readwrite creds) apps; one
# HTTPRoute routes by method. The DB starts empty — the Job owns the schema.
cd stacks/part3-infra  && terragrunt stack run apply
cd ../part3-config     && terragrunt stack run apply

# Part 4 — Keycloak, then realm config + OpenBao OIDC (wait for Keycloak ready between)
cd stacks/part4-infra  && terragrunt stack run apply
kubectl -n keycloak rollout status statefulset/keycloak --timeout=5m
cd ../part4-config     && terragrunt stack run apply
# then harden: create the automation service account and remove the bootstrap admin
./set-demo-user-passwords.sh
./harden-remove-bootstrap-admin.sh

# Part 4 (SSO to Gitea) — register the Keycloak login source in Gitea, then log
# into Gitea with the same users. The keycloak-config stack already created the
# "gitea" OIDC client (secret in OpenBao at secret/keycloak/gitea-oidc-client).
./configure-gitea-oidc.sh
# Now http://gitea.${MY_PRIVATE_IP}.nip.io shows "Sign in with keycloak".

# Part 4 (CI/CD run) — deploy the Actions runner and register it, then (as your
# SSO user) create a repo + .gitea/workflows action and watch the pipeline run.
cd stacks/part4-cicd && terragrunt stack run apply   # (from the lab root)
./register-gitea-runner.sh        # mints a runner token (admin creds from OpenBao) and registers it
# See the end of Part 4 for the full SSO-login -> git-CLI repo+action -> watch-logs walkthrough.

# Part 5 — Leak detection: observability stack, then canary + alert rules
#   part5-infra installs a lean Loki + Alloy + Grafana. OpenBao's audit device
#   already writes JSON to stdout (Part 1), so Alloy ships it to Loki with no
#   extra wiring. The Grafana admin password is generated and stored at
#   secret/grafana/admin (never in state).
cd stacks/part5-infra  && terragrunt stack run apply
kubectl -n monitoring rollout status deploy/grafana --timeout=5m

#   part5-config plants the canary and creates the Grafana alert rules. The
#   alerts unit drives the grafana provider, so it needs GRAFANA_URL + GRAFANA_AUTH.
#   GRAFANA_URL MUST use $MY_PRIVATE_IP (the host the infra stack routed Grafana
#   to). If MY_PRIVATE_IP is empty it falls back to grafana.127.0.0.1.nip.io,
#   which the gateway can't route -> every call fails with a 404 on POST /folders.
export GRAFANA_URL="http://grafana.${MY_PRIVATE_IP}.nip.io"
GRAFANA_PW=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/secret/data/grafana/admin" | jq -r .data.data.password)
export GRAFANA_AUTH="admin:${GRAFANA_PW}"

# Sanity check — expect 200 before applying part5-config:
curl -s -o /dev/null -w '%{http_code}\n' -u "$GRAFANA_AUTH" "$GRAFANA_URL/api/folders"

cd ../part5-config     && terragrunt stack run apply
```

> **Already ran the Observability series in this cluster?** Set `install_loki`/
> `install_alloy`/`install_grafana = false` in the `observability` unit's values
> (in `stacks/part5-infra`) to reuse the existing Loki/Alloy/Grafana instead of
> installing a second copy, then point `GRAFANA_URL`/`GRAFANA_AUTH` at it.
>
> **Federation, external API keys, and cloud mappings** in the Part 5 article are
> illustrative production reference — they are not part of this single-cluster lab.

## Re-applying and rebuilding (state drift)

OpenBao (Raft) and Grafana store state **independently of Terraform**. If an apply fails partway, or you clear local Terraform state and re-apply against a still-running datastore, you can hit "already exists" errors. On a full clean rebuild (fresh cluster) these don't occur; they only bite on partial re-runs. Quick fixes:

- **`path is already in use at <mount>/`** (OpenBao auth mount from a prior run, e.g. `jwt-gitea` or `oidc`): delete the orphan, then re-apply.
  ```bash
  curl -s --request DELETE -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/auth/<mount>"
  curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/auth" | jq '.data | keys'
  ```
- **Grafana `createFolderConflict` (409)** on `part5-config`: the "Security - Credentials" folder exists from a prior run. Delete it (removes its alert rules too) and re-apply.
  ```bash
  FUID=$(curl -s -u "$GRAFANA_AUTH" "$GRAFANA_URL/api/folders" | jq -r '.[]|select(.title=="Security - Credentials")|.uid')
  [ -n "$FUID" ] && curl -s -u "$GRAFANA_AUTH" -X DELETE "$GRAFANA_URL/api/folders/$FUID"
  ```
- **After rebuilding `part5-infra`**, the Grafana admin password is regenerated — always **re-derive `GRAFANA_AUTH`** from `secret/grafana/admin` (below) before applying `part5-config`, or the grafana provider fails auth against the new Grafana.
- **Gitea login source / runner** self-heal: re-running `configure-gitea-oidc.sh` (delete+add) and `register-gitea-runner.sh` (re-mints the token) is safe and idempotent.

## Where the secrets live

No password is in git or Terraform state. Generated secrets are stored in OpenBao KV (`secret/…`):

| Secret | OpenBao path |
|--------|--------------|
| PostgreSQL admin | `secret/postgres/admin` |
| Gitea admin | `secret/gitea/admin` |
| Keycloak bootstrap admin | `secret/keycloak/bootstrap-admin` |
| OpenBao OIDC client | `secret/keycloak/openbao-oidc-client` |
| Gitea OIDC client (SSO) | `secret/keycloak/gitea-oidc-client` |
| Terraform admin service account | `secret/keycloak/terraform-admin` |
| Demo human users (temp passwords) | `secret/keycloak/users/<user>` |
| Grafana admin (Part 5) | `secret/grafana/admin` |

> The one deliberate exception is the Part 5 **canary** at `secret/database/production-admin` — an obviously-fake honey-token that exists only to be detected. It grants access to nothing; any read of it is a leak/probe signal.

Retrieve one, e.g.:

```bash
curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/secret/data/postgres/admin" | jq -r .data.data.password
```

## Series Links

- Part 1: Foundations — Principles, OpenBao Architecture & The Secret Zero Problem
- Part 2: Service-to-Service — JWT, mTLS (SPIFFE) & CI/CD Pipeline Credentials
- Part 3: App-to-Database — Just-In-Time Dynamic Credentials
- Part 4: Human Authentication — OIDC Federation, MFA & Break-Glass
- Part 5: Leak Detection, Cross-Boundary Federation & External Integrations (leak detection runnable; federation/external/cloud illustrative)
