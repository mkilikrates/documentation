# Deploying a httproute

This will deploy 2 [pod](https://kubernetes.io/docs/concepts/workloads/pods/) and [service](https://kubernetes.io/docs/concepts/services-networking/service/)/[Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/) on [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) `red-blue-httproute`  so it can access each pod based on uri (red or blue)

## agnhost

[Official documentation about this image](https://pkg.go.dev/k8s.io/kubernetes/test/images/agnhost#section-readme)

It will deploy 2 pods using [red-blue-httproute.yaml file](red-blue-httproute.yaml)

```bash
kubectl apply -f red-blue-httproute.yaml
```

You can check that it is running using

```bash
kubectl -n red-blue-httproute get all
```

It will show something like this:

```bash
NAME           READY   STATUS    RESTARTS   AGE
pod/blue-app   1/1     Running   0          10m
pod/red-app    1/1     Running   0          10m

NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/blue-service   ClusterIP   10.109.220.216   <none>        8080/TCP   10m
service/red-service    ClusterIP   10.106.186.195   <none>        8080/TCP   10m
```

you can check details on your gateway using:

```bash
kubectl -n red-blue-httproute get gatewayclass
kubectl -n red-blue-httproute get gateway
kubectl -n red-blue-httproute get httproute
```

Finally you can access using your browser

* [app-red](http://127.0.0.1:80/red)
* [app-blue](http://127.0.0.1:80/blue)

 or can test using curl

```bash
curl http://127.0.0.1/red
curl http://127.0.0.1/blue
```

## clean up

To clean up you can remove using this

```bash
kubectl delete -f red-blue-httproute.yaml
```