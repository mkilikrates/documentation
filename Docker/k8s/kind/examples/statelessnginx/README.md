# Deploying a simple nginx

This will deploy a simple nginx [pod](https://kubernetes.io/docs/concepts/workloads/pods/) on [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) `statelessnginx`

## nginx

[Official documentation about this image](https://hub.docker.com/_/nginx)

To deploy a nginx pods using [nginxpod.yaml](nginxpod.yaml)

```bash
kubectl apply -f nginxpod.yaml
```

You can check that it is running using

```bash
kubectl -n statelessnginx get all
```

It will show something like this:

```bash
NAME                  READY   STATUS    RESTARTS   AGE
pod/stateless-nginx   1/1     Running   0          4s
```

Then you can expose locally (host) the pod por to test

```bash
kubectl -n statelessnginx port-forward pods/stateless-nginx 8080:80
```

Finally you can access using your browser on http://127.0.0.1:8080/ or can test using curl

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080
```

## clean up

To clean up you can remove using this

```bash
kubectl delete -f nginxpod.yaml
```
