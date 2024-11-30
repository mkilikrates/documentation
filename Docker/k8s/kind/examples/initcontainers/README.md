# Deploying a nginx with custom index page showing POD IP address

This will create a [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) with 3 [pods](https://kubernetes.io/docs/concepts/workloads/pods/) in a [replicaset](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/) and and [service/load-balancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer)/[ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) on [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) `initcontainer`.

It will create a custom index.html page as [ephemeral volume](https://kubernetes.io/docs/concepts/storage/ephemeral-volumes/) in each POD that will be mounted by each [init container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) as Read-Write to create the index.html file that will be mounted by main container (nginx) as Read-Only to delivery page.

With this, each pod will show a different page, since it will show their IP address.

## nginx

[Official documentation about this image](https://hub.docker.com/_/nginx)

## busybox

[Official documentation about this image](https://hub.docker.com/_/busybox/)

It will deploy 3 pods using [nginx-busybox-initcontainer.yaml](nginx-busybox-initcontainer.yaml)

```bash
kubectl apply -f nginx-busybox-initcontainer.yaml
```

You can check that it is running using

```bash
kubectl -n initcontainer get all
```

It will show something like this:

```bash
NAME                               READY   STATUS    RESTARTS   AGE
pod/nginx-deploy-56d48b74c-4m6dh   1/1     Running   0          40s
pod/nginx-deploy-56d48b74c-7q596   1/1     Running   0          40s
pod/nginx-deploy-56d48b74c-98qvr   1/1     Running   0          40s

NAME                       TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/nginx-ip-service   LoadBalancer   10.96.133.185   <pending>     80:32451/TCP   40s

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deploy   3/3     3            3           40s

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deploy-56d48b74c   3         3         3       40s
```

Finally you can access using your browser, as you refresh the page, you will notice that it will show different IP address.

* [app](http://127.0.0.1:80/)

 or can test using curl

```bash
while true; do curl http://127.0.0.1; echo ""; sleep 1; done
```

You can see response from both pods

```bash
Hello, World! Your Pod IP is:
10.244.3.7

Hello, World! Your Pod IP is:
10.244.1.10

Hello, World! Your Pod IP is:
10.244.1.10

Hello, World! Your Pod IP is:
10.244.3.7

Hello, World! Your Pod IP is:
10.244.3.7

Hello, World! Your Pod IP is:
10.244.4.7
```

To cancel it, use `<CTRL>+<c>`

*Note*: You can see all steps with the following cli

```bash
kubectl -n initcontainer events
--for pod/nginx-deploy-56d48b74c-fch2x
```

It will show something like this:

```bash
LAST SEEN   TYPE     REASON      OBJECT                             MESSAGE
2m39s       Normal   Pulling     Pod/nginx-deploy-56d48b74c-fch2x   Pulling image "busybox"
2m39s       Normal   Scheduled   Pod/nginx-deploy-56d48b74c-fch2x   Successfully assigned initcontainer/nginx-deploy-56d48b74c-fch2x to kind-worker2
2m38s       Normal   Pulled      Pod/nginx-deploy-56d48b74c-fch2x   Successfully pulled image "busybox" in 877ms (877ms including waiting). Image size: 2167126 bytes.
2m38s       Normal   Created     Pod/nginx-deploy-56d48b74c-fch2x   Created container write-ip
2m38s       Normal   Started     Pod/nginx-deploy-56d48b74c-fch2x   Started container write-ip
2m37s       Normal   Pulling     Pod/nginx-deploy-56d48b74c-fch2x   Pulling image "busybox"
2m36s       Normal   Pulled      Pod/nginx-deploy-56d48b74c-fch2x   Successfully pulled image "busybox" in 866ms (866ms including waiting). Image size: 2167126 bytes.
2m36s       Normal   Created     Pod/nginx-deploy-56d48b74c-fch2x   Created container create-html
2m36s       Normal   Started     Pod/nginx-deploy-56d48b74c-fch2x   Started container create-html
2m35s       Normal   Pulling     Pod/nginx-deploy-56d48b74c-fch2x   Pulling image "nginx"
2m34s       Normal   Pulled      Pod/nginx-deploy-56d48b74c-fch2x   Successfully pulled image "nginx" in 848ms (848ms including waiting). Image size: 72996017 bytes.
2m34s       Normal   Created     Pod/nginx-deploy-56d48b74c-fch2x   Created container web-container
2m34s       Normal   Started     Pod/nginx-deploy-56d48b74c-fch2x   Started container web-container
```

## clean up

To clean up you can remove using this

```bash
kubectl delete -f nginx-busybox-initcontainer.yaml
```
