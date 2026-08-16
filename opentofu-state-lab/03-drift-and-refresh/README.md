# Phase 3 — Drift Detection and Refresh

In the real world, people make changes outside of your IaC tool. This phase simulates that scenario and teaches you how to detect and handle drift.

## What is Drift?

Drift occurs when the actual state of your infrastructure differs from what OpenTofu expects (based on the state file). Common causes:

- Manual `kubectl` or `helm` commands
- Another team member making changes
- Automated processes (operators, autoscalers)
- Emergency hotfixes applied directly

## Detecting Drift

There are two ways to detect drift, and they differ in **what they consider the source of truth**:

### `tofu plan` — Source of truth is your CODE

```
+-------------------+         +-------------------+         +-------------------+
|  Live Cluster     |--refresh-->  State File     |<--compare--|  .tf files       |
|  (actual)         |         |  (updated from    |         |  (desired)        |
|                   |         |   live first)     |         |    WINS -->       |
+-------------------+         +-------------------+         +-------------------+

1. State is refreshed from live (state now matches reality)
2. Code is compared against refreshed state
3. Plan shows API calls needed to make LIVE match CODE
   "replicas is 5 in live, code says 2 -> I will scale down to 2"
```

### `tofu plan -refresh-only` — Source of truth is the LIVE infrastructure

```
+-------------------+         +-------------------+         +-------------------+
|  Live Cluster     |--refresh-->  State File     |         |  .tf files        |
|  (actual)         |         |  (to update)      |         |  (not compared)   |
|    WINS -->       |         |                   |         |                   |
+-------------------+         +-------------------+         +-------------------+

1. State is refreshed from live
2. Plan shows what CHANGED between old state and live
3. On apply: state file is updated, NO infrastructure changes
   "replicas was 2 in state, live has 5 -> I will record 5 in state"
```

### Side by Side

| | `tofu plan` | `tofu plan -refresh-only` |
|---|---|---|
| **Source of truth** | Your `.tf` code (intended state) | Live infrastructure (actual state) |
| **First step** | Refresh state from live | Refresh state from live |
| **Then** | Compare code vs refreshed state | Show diff between old state and live |
| **On apply** | Makes API calls to change infrastructure | Only updates the state file |
| **Infrastructure impact** | Yes — creates, updates, destroys resources | None — only the state file changes |
| **Use when** | You want reality to match your code | You want to acknowledge reality |

---

## Exercises

### Exercise 1 — Helm Upgrade Drift

Someone upgrades NGINX Gateway Fabric manually to fix a critical bug:

```bash
helm upgrade ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  -n nginx-gateway \
  --version 2.6.7 \
  --set nginx.service.type=NodePort \
  --set-json 'nginx.service.nodePorts=[{"name":"http","port":31437,"listenerPort":80},{"name":"https","port":31438,"listenerPort":443}]' \
  --set-json 'nginxGateway.nodeSelector={"kubernetes.io/hostname":"kind-control-plane"}'
```

Now detect the drift — try both:

```bash
cd ../02-deploy/infra

# Detect drift: what would OpenTofu change to match code?
tofu plan

# Detect drift: what changed in live vs state?
tofu plan -refresh-only
```

**`tofu plan` shows:** "I will downgrade from 2.6.7 back to 2.6.6" (code wins)

**`tofu plan -refresh-only` shows:** "version changed from 2.6.6 to 2.6.7 in live" (live wins)

**Option A — Accept the change (refresh-only):**

This updates the state file to reflect reality without reverting the upgrade:

```bash
tofu apply -refresh-only
```

Review the changes and type `yes`. The state now records version `2.6.7`.

Now you **must** update your code to match, otherwise the next `tofu plan` will try to downgrade again:

```bash
# Update the default version in variables.tf
sed -i 's/default     = "2.6.6"/default     = "2.6.7"/' variables.tf
```

Verify the code and state are in sync:

```bash
tofu plan
# Should show: "No changes. Your infrastructure matches the configuration."
```

> **Key lesson:** `refresh-only` buys you time, but it's not the end of the story. You must align your code with reality — otherwise the next plan will create drift in the opposite direction (code trying to undo what you just accepted).

**Option B — Revert the change:**

A regular `tofu apply` would downgrade back to `2.6.6` (the version in your config). This is useful if the manual change was unauthorized.

```bash
tofu apply
```

> **For this lab:** Use Option A (refresh-only) so we keep the upgraded version.

---

### Exercise 2 — Replica Scaling Drift

Someone scales the red app manually during an incident:

```bash
kubectl -n red scale deployment red-app --replicas=5
```

Detect it — try both approaches:

```bash
cd ../02-deploy/apps

# What would OpenTofu do? (code is source of truth)
tofu plan

# What changed in live? (live is source of truth)
tofu plan -refresh-only
```

**`tofu plan` shows:** `replicas: 5 -> 2` — "I will scale back down" (code wins)

**`tofu plan -refresh-only` shows:** `replicas: 2 -> 5` — "state is outdated, live has 5" (live wins)

**Discussion:**
- If this was an emergency scale, you might `apply -refresh-only` and then update your `.tf` to 5 replicas
- If it was accidental, just `tofu apply` to revert to 2

For this lab, revert it:

```bash
tofu apply
```

---

### Exercise 3 — ConfigMap Attribute Drift

Someone edits the blue app's HTML directly:

```bash
kubectl -n blue edit configmap blue-html
```

Change the `<h1>` text from "Blue App" to "Blue App (HOTFIX)" and save.

> **Important:** Kubernetes does NOT automatically restart pods when a ConfigMap changes. The running pods still serve the old content from their mounted volume cache. You'd need a `kubectl rollout restart deployment/blue-app -n blue` to pick up the new ConfigMap. Our OpenTofu deployment handles this automatically — see below.

Detect it:

```bash
# What would OpenTofu do?
tofu plan

# What changed in live?
tofu plan -refresh-only
```

**`tofu plan` shows:** the exact diff of the ConfigMap data — it will revert the HTML content back to what's defined in `app_blue.tf`. It will also show a deployment change because the `configmap-hash` annotation updates.

**`tofu plan -refresh-only` shows:** the ConfigMap data changed — state is outdated.

Apply to revert:

```bash
tofu apply
```

**How we force the rollout:** The deployment has a pod annotation with a hash of the ConfigMap content:

```hcl
annotations = {
  "configmap-hash" = sha256(jsonencode(kubernetes_config_map.blue_html.data))
}
```

When the ConfigMap changes (either through drift revert or a legitimate update), the hash changes, the pod template changes, and Kubernetes triggers a rolling update. This ensures pods always serve the current ConfigMap content.

---

## Key Takeaways

| Scenario | Best Response |
|----------|---------------|
| Intentional change you want to keep | `tofu apply -refresh-only` then update `.tf` files |
| Accidental/unauthorized change | `tofu apply` (reverts to desired state) |
| Emergency change, need time to decide | `tofu apply -refresh-only` (buys time without reverting) |

## The Mental Model

```
           tofu apply                       tofu apply -refresh-only
    +-----------------------+         +-------------------------------+
    |                       |         |                               |
    |  CODE --> LIVE        |         |  LIVE --> STATE               |
    |  (code wins)          |         |  (live wins)                  |
    |                       |         |                               |
    |  "Make reality        |         |  "Accept reality              |
    |   match my intent"    |         |   into my records"            |
    +-----------------------+         +-------------------------------+
```

After `refresh-only`, your state matches reality but your `.tf` files don't. You **must** update the code to match, or the next `tofu plan` will show the same drift in reverse (trying to undo what you just accepted). The workflow is always:

1. `tofu apply -refresh-only` — accept reality into state
2. Update `.tf` files to match the new reality
3. `tofu plan` — confirm "No changes"

## Why You Can't Just Update the Code

A tempting shortcut: "I see drift on the version. I'll just change my `.tf` to match live and run `apply` — skip the `refresh-only` step."

For simple attribute updates, this often works because `tofu plan` auto-refreshes state from live before comparing. But the state file isn't just a cache — it's the **management boundary**. It defines what OpenTofu thinks it owns.

Consider what happens with force-replacement attributes:

1. You have a deployment with `name = "blue-app"` in code, state, and live
2. Someone deletes it and creates `name = "blue-app-v2"` in the cluster
3. You just change your code to `name = "blue-app-v2"` and apply
4. OpenTofu refreshes, can't find `blue-app` (gone), plans to **create** `blue-app-v2` — but it already exists. Apply fails or creates a conflict.

The same pattern hits with:
- **Immutable fields** (like `selector` on a Deployment) — provider plans destroy + create
- **Resources recreated externally** — they exist in live but state doesn't track them
- **Namespace changes** — the resource gets recreated rather than moved

**The rule:** If reality changed, update state first (`refresh-only`), then update code. Skipping the state update means the decision-maker (state) has stale information.

```
Safe workflow:
  1. Detect drift        → tofu plan -refresh-only
  2. Accept into state   → tofu apply -refresh-only
  3. Update code         → edit .tf files to match
  4. Verify              → tofu plan ("No changes")

Risky shortcut:
  1. See drift
  2. Just update code and apply
  3. Hope the provider handles it
     → Works sometimes, fails dangerously on force-new attributes
```

## Beyond This Lab: Lifecycle Rules

OpenTofu provides `lifecycle` blocks to control how resources are managed. While we don't exercise these here, they're worth knowing:

| Rule | Behavior | Use Case |
|------|----------|----------|
| `create_before_destroy = true` | New resource is created before the old one is destroyed | Zero-downtime replacements (databases, load balancers) |
| `prevent_destroy = true` | Errors out if a plan would destroy the resource | Protect critical resources (production DBs, encryption keys) |
| `ignore_changes = [field]` | Ignores drift on specific fields | Fields managed by autoscalers or operators (e.g., `replicas`) |
| `replace_triggered_by = [ref]` | Forces replacement when a referenced resource changes | Recreate pods when a ConfigMap changes |

For example, if you wanted OpenTofu to ignore replica drift (because an HPA manages it):

```hcl
resource "kubernetes_deployment" "red" {
  # ...
  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}
```

With this in place, `tofu plan` would NOT show drift on replicas — OpenTofu would skip that field entirely. This is common in production when autoscalers or operators manage certain fields.

> **Further reading:** [OpenTofu Lifecycle Documentation](https://opentofu.org/docs/language/meta-arguments/lifecycle/)

## Next Step

Proceed to [04-import-and-remove](../04-import-and-remove/) to learn how to handle resources created or deleted outside OpenTofu.
