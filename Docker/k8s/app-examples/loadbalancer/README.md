# Deploying a ingress with load balancer

This will deploy 2 [pod](https://kubernetes.io/docs/concepts/workloads/pods/) and [service/loadBalancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer)/[ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) on [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) `red-blue-lb` so it will balancer and alternate response between then (red or blue)

## agnhost

[Official documentation about this image](https://pkg.go.dev/k8s.io/kubernetes/test/images/agnhost#section-readme)

It will deploy 2 pods using [load-balancer-service.yaml file](load-balancer-service.yaml)

```bash
kubectl apply -f load-balancer-service.yaml
```

You can check that it is running using

```bash
kubectl -n red-blue-lb get all
```

It will show something like this:

```bash
NAME           READY   STATUS    RESTARTS   AGE
pod/blue-app   1/1     Running   0          51s
pod/red-app    1/1     Running   0          51s

NAME                       TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
service/red-blue-service   LoadBalancer   10.96.75.34   <pending>     80:32719/TCP   51s
```

Finally you can access using your browser, as you refresh the page, you will notice that it will alternate between red-app and blue-app.

* [app](http://127.0.0.1:80/)

 or can test using curl

```bash
while true; do curl http://127.0.0.1; echo ""; sleep 1; done
```

You can see response from both pods

```bash
red-app
red-app
blue-app
blue-app
blue-app
blue-app
blue-app
red-app
```

To cancel it, use `<CTRL>+<c>`

## clean up

To clean up you can remove using this

```bash
kubectl delete -f load-balancer-service.yaml
```
