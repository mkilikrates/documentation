# CERT-MANAGER

cert-manager creates TLS certificates for workloads in your Kubernetes or OpenShift cluster and renews the certificates before they expire.

cert-manager can obtain certificates from a variety of certificate authorities, including: Let's Encrypt, HashiCorp Vault, CyberArk Certificate Manager and private PKI.

[Official Documentation](https://cert-manager.io/)

## Installation using helm

```bash
export certmanversion=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/cert-manager/cert-manager/releases/latest | awk -F "/" '{print $NF}' | cut -c2-)
helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v${certmanversion} \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true
```

## Create a self signed issuer

```bash
kubectl apply -f self-issuer.yaml
```

For other issuers see [official documentation](https://letsencrypt.org/docs/)

## Create ingress or [gateway](../nginx-fabric/) targeting this certificate 

## Clean up

```bash
helm uninstall cert-manager --namespace cert-manager
kubectl delete crd \
  issuers.cert-manager.io \
  clusterissuers.cert-manager.io \
  certificates.cert-manager.io \
  certificaterequests.cert-manager.io \
  orders.acme.cert-manager.io \
  challenges.acme.cert-manager.io
```
