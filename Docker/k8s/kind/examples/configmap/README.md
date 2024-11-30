# Deploying a nginx with custom index page using configmap

This will create a [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) with 3 [pods](https://kubernetes.io/docs/concepts/workloads/pods/) in a [replicaset](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/) and and [service](https://kubernetes.io/docs/concepts/services-networking/service/)/[ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) on [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) `configmap-content`.

It will create a custom index.html page as [config-map](https://kubernetes.io/docs/concepts/configuration/configmap/) that will be mounted by each pod as Read-Only [Volume](https://kubernetes.io/docs/concepts/storage/volumes/#configmap).

With this, any change in the config-map will update their content in all pods.

## nginx

[Official documentation about this image](https://hub.docker.com/_/nginx)

It will deploy 2 pods using [configmap-content.yaml](configmap-content.yaml)

```bash
kubectl apply -f configmap-content.yaml
```

Note the output with resources created:

```bash
namespace/configmap-content created
configmap/index-html-configmap created
deployment.apps/nginx-app created
service/nginx-configmap-service created
ingress.networking.k8s.io/nginx-configmap-ingress created
```

You can check that it is running using

```bash
kubectl -n configmap-content get all
```

It will show something like this:

```bash
NAME                             READY   STATUS    RESTARTS   AGE
pod/nginx-app-6b544fc66b-26dzq   1/1     Running   0          2m
pod/nginx-app-6b544fc66b-n84g4   1/1     Running   0          2m
pod/nginx-app-6b544fc66b-wxw7k   1/1     Running   0          2m

NAME                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/nginx-configmap-service   ClusterIP   10.96.128.58   <none>        80/TCP    2m

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-app   3/3     3            3           2m

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-app-6b544fc66b   3         3         3       2m
```

*NOTE*: That not all resources appears here, for instance configmap and ingress.

So if we want see our configmap you need to use this

```bash
kubectl -n configmap-content get configmaps
```

Finally you can access using your browser

* [app](http://127.0.0.1:80/)

 or can test using curl

```bash
curl http://127.0.0.1
```

Let's now test update this page using the following line

```bash
kubectl -n configmap-content edit configmaps index-html-configmap
```

It will appears a page like vi/vim editor with similar configuration that you can see in [configmap-content.yaml](configmap-content.yaml) file. In my case I will add the following line before close Body `</body>`:

```html
<p> This is my change</p>
```

Save and exit it will automatically apply this change.

*NOTE*: That it will take few seconds before you see that when accessing the page since each instance will update their content as well as nginx by default peform some caching.

## clean up

To clean up you can remove using this

```bash
kubectl delete -f configmap-content.yaml
```
