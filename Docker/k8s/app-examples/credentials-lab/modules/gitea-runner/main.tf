# Gitea Actions Runner (act_runner) for the CI/CD demo (Part 2).
#
# Gitea has Actions ENABLED (see the gitea module), but a runner must register
# with Gitea to actually execute jobs. Registration needs a one-time token that
# Gitea mints; that token is NOT a Terraform-knowable value, so we follow the
# lab's "bootstrap secret, then use" pattern:
#
#   1. This module creates an empty-ish placeholder Secret (gitea-runner-token)
#      and the act_runner Deployment that consumes it.
#   2. register-gitea-runner.sh mints a registration token from Gitea's API
#      (admin creds read from OpenBao — no static secret) and writes it into that
#      Secret, then restarts the runner so it registers.
#
# We deliberately do NOT put the registration token in Terraform state: the
# script populates the Secret out-of-band, and the Deployment reads it at runtime.
#
# Runner execution mode: this uses the act_runner "host" / native mode driving a
# shared Docker-in-Docker sidecar, so jobs run in containers without needing a
# node Docker socket. Kept minimal for a Kind lab.

resource "kubernetes_service_account" "runner" {
  metadata {
    name      = "gitea-runner"
    namespace = var.namespace
  }
}

# Placeholder Secret for the runner registration token. The register script
# fills in `token` at runtime; until then it holds an empty token, so the pod
# starts and act_runner just retries registration (rather than the pod failing
# with CreateContainerConfigError).
resource "kubernetes_secret_v1" "runner_token" {
  metadata {
    name      = var.token_secret_name
    namespace = var.namespace
  }
  type = "Opaque"

  # Seed an EMPTY token so the key exists from the start. Without it, the pod
  # fails with CreateContainerConfigError ("couldn't find key token") in the
  # window before register-gitea-runner.sh runs. With an empty value the pod
  # starts and act_runner simply fails to register (a normal retry) until the
  # script patches a real token in.
  data = {
    token = ""
  }

  # Managed out-of-band by register-gitea-runner.sh (it patches `token`).
  # Ignore changes so a later apply doesn't wipe the registered token.
  lifecycle {
    ignore_changes = [data, data_wo]
  }
}

# act_runner config: register against the in-cluster Gitea service, label the
# runner so `runs-on: ubuntu-latest` (and `runs-on: node`) resolve to an image.
resource "kubernetes_config_map" "runner_config" {
  metadata {
    name      = "gitea-runner-config"
    namespace = var.namespace
  }
  data = {
    "config.yaml" = <<-YAML
      log:
        level: info
      runner:
        capacity: ${var.runner_capacity}
        timeout: 3h
        labels:
          - "ubuntu-latest:docker://${var.default_job_image}"
          - "node:docker://${var.default_job_image}"
      cache:
        enabled: false
    YAML
  }
}

resource "kubernetes_deployment" "runner" {
  metadata {
    name      = "gitea-runner"
    namespace = var.namespace
    labels    = { app = "gitea-runner", "app.kubernetes.io/part-of" = "credentials-lab" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "gitea-runner" }
    }
    template {
      metadata {
        labels = { app = "gitea-runner" }
      }
      spec {
        service_account_name = kubernetes_service_account.runner.metadata[0].name

        # Docker-in-Docker sidecar so Actions jobs can run in containers.
        container {
          name  = "dind"
          image = var.dind_image
          security_context {
            privileged = true
          }
          env {
            name  = "DOCKER_TLS_CERTDIR"
            value = ""
          }
          volume_mount {
            name       = "docker-sock"
            mount_path = "/var/run"
          }
        }

        container {
          name  = "runner"
          image = var.runner_image

          # act_runner reads registration inputs from env; the daemon registers
          # on first start using GITEA_RUNNER_REGISTRATION_TOKEN, then persists
          # its own credential in .runner (emptyDir here — re-registers on
          # restart, which is fine for a lab).
          env {
            name  = "GITEA_INSTANCE_URL"
            value = var.gitea_internal_url
          }
          env {
            name = "GITEA_RUNNER_REGISTRATION_TOKEN"
            value_from {
              secret_key_ref {
                name     = kubernetes_secret_v1.runner_token.metadata[0].name
                key      = "token"
                optional = true
              }
            }
          }
          env {
            name  = "GITEA_RUNNER_NAME"
            value = "kind-runner"
          }
          env {
            name  = "DOCKER_HOST"
            value = "tcp://localhost:2375"
          }
          env {
            name  = "CONFIG_FILE"
            value = "/config/config.yaml"
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }
          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        volume {
          name = "docker-sock"
          empty_dir {}
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.runner_config.metadata[0].name
          }
        }
        volume {
          name = "data"
          empty_dir {}
        }
      }
    }
  }

  # The registration token Secret must exist; the register script fills it in.
  depends_on = [kubernetes_secret_v1.runner_token]
}
