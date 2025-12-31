# Using kubernetes-dashboard emulate and test kubernetes

Web UI to access your Kubernetes cluster

## Installation

In this example the installation will be executed using [helm](https://helm.sh/).

[Official Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/) or in their [Github](https://github.com/kubernetes/dashboard/tree/master)

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
 --create-namespace --namespace kubernetes-dashboard \
 --set app.ingress.enabled=true \
 --set app.ingress.ingressClassName=nginx \
 --set app.ingress.hosts="{host.docker.internal}" \
 --set app.ingress.path="/dashboard($|/)?(.*)" \
 --set extras.serviceMonitor.enabled=true \
 --set extras.serviceMonitor.additionalLabels.release="prometheus-stack"
```

This will install this chart and expose this service in https (443) under the name of `https://host.docker.internal/dashboard/`.

*Note*: The latest 2 lines are to expose metrics to prometheus.

Then we will need a [service account/user](user.yaml) and token to authenticate against this:

```bash
kubectl apply -f user.yaml
```

Then you can get the token

```bash
kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath="{.data.token}" | base64 -d; echo
```

Now you will have access to main dashboards exposed:

- [dashboard](https://host.docker.internal/dashboard) - use the token value from the previous command. 

## clean up

To clean up you can remove using this

```bash
helm -n kubernetes-dashboard uninstall kubernetes-dashboard
kubectl delete namespaces kubernetes-dashboard
```
