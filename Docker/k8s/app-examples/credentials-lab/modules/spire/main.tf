# SPIFFE/SPIRE — Workload Identity
# Deploys SPIRE Server + Agent via Helm (same setup as Security Series Part 1)

resource "kubernetes_namespace" "spire" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "credentials-lab"
    }
  }
}

# cert-manager is a prerequisite for SPIRE's upstream authority
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  namespace  = "cert-manager"

  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    name  = "crds.enabled"
    value = "true"
  }
}

# Self-signed root CA for SPIRE
resource "null_resource" "cert_manager_ca_chain" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<EOF
      ---
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: selfsigned-root
      spec:
        selfSigned: {}
      ---
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: spire-root-ca
        namespace: ${var.namespace}
      spec:
        isCA: true
        commonName: "SPIRE Root CA"
        duration: 87600h
        secretName: spire-root-ca-secret
        privateKey:
          algorithm: ECDSA
          size: 256
        issuerRef:
          name: selfsigned-root
          kind: ClusterIssuer
          group: cert-manager.io
      ---
      apiVersion: cert-manager.io/v1
      kind: Issuer
      metadata:
        name: spire-ca-issuer
        namespace: ${var.namespace}
      spec:
        ca:
          secretName: spire-root-ca-secret
      EOF
    EOT
  }

  triggers = {
    namespace = var.namespace
  }
}

# SPIRE CRDs
resource "helm_release" "spire_crds" {
  name       = "spire-crds"
  repository = "https://spiffe.github.io/helm-charts-hardened/"
  chart      = "spire-crds"
  namespace  = var.namespace

  wait = true

  depends_on = [kubernetes_namespace.spire]
}

# SPIRE Server + Agent
resource "helm_release" "spire" {
  name       = "spire"
  repository = "https://spiffe.github.io/helm-charts-hardened/"
  chart      = "spire"
  version    = var.spire_chart_version
  namespace  = var.namespace

  wait    = true
  timeout = 600

  values = [yamlencode({
    global = {
      spire = {
        trustDomain = var.trust_domain
        clusterName = var.cluster_name
        namespaces = {
          create = false
        }
      }
    }

    spire-server = {
      replicaCount = 1
      caSubject = {
        country      = "IE"
        organization = "CredentialsLab"
        commonName   = "SPIRE CA"
      }
      upstreamAuthority = {
        certManager = {
          enabled    = true
          issuerName = "spire-ca-issuer"
          issuerKind = "Issuer"
          issuerGroup = "cert-manager.io"
          namespace  = var.namespace
          kubeConfigFile = ""
          ca = {
            create = false
          }
        }
      }
      nodeAttestor = {
        k8sPSAT = {
          enabled              = true
          serviceAccountAllowList = []
        }
      }
      controllerManager = {
        enabled = true
        identities = {
          clusterSPIFFEIDs = {
            default = {
              enabled           = true
              spiffeIDTemplate  = "spiffe://{{ .TrustDomain }}/ns/{{ .PodMeta.Namespace }}/sa/{{ .PodSpec.ServiceAccountName }}"
              namespaceSelector = {}
              podSelector       = {}
            }
            oidc-discovery-provider = { enabled = false }
            test-keys               = { enabled = false }
            spike-keeper            = { enabled = false }
            spike-nexus             = { enabled = false }
            spike-bootstrap         = { enabled = false }
            spike-pilot             = { enabled = false }
          }
        }
      }
    }

    spire-agent = {
      nameOverride = "agent"
    }

    spiffe-csi-driver = {
      enabled = true
    }

    spiffe-oidc-discovery-provider = {
      enabled = false
    }
  })]

  depends_on = [
    helm_release.spire_crds,
    null_resource.cert_manager_ca_chain
  ]
}
