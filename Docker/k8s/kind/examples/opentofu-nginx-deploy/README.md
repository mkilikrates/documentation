# Deploying a simple nginx

This will deploy 2 nginx [pod](https://kubernetes.io/docs/concepts/workloads/pods/) in a [service](https://kubernetes.io/docs/concepts/services-networking/service/)/[ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) on [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) `scalable-nginx` set on variable file [terraform.tfvars](terraform.tfvars)

## nginx

[Official documentation about this image](https://hub.docker.com/_/nginx)

## opentofu

[Official documentation about this image](https://opentofu.org/docs/intro/install/docker/)

To deploy a this using [kubernetes.tf](kubernetes.tf)

```bash
# To initialize
tofu init
# To check what will be applied
tofu plan
# To deploy
tofu apply
```

Instead of [install opentofu](https://opentofu.org/docs/intro/install/) you can use their docker as bellow:

```bash
docker run -v ${PWD}:/opt/app -w /opt/app -v ~/.kube/config:/root/.kube/config -t -i --rm ghcr.io/opentofu/opentofu:latest <command> <options>
```

*Note*: Since in my configuration I want to use credentials from my local WSL, it is being mounted with '-v', details can be found on [Docker documentation](https://docs.docker.com/engine/storage/bind-mounts/)

*Steps documentation*:
- [init](https://opentofu.org/docs/cli/commands/init/)
- [plan](https://opentofu.org/docs/cli/commands/plan/)
- [apply](https://opentofu.org/docs/cli/commands/apply/)

You can check that it is running using

```bash
kubectl -n scalable-nginx get all
```

It will show something like this:

```bash
NAME                                  READY   STATUS    RESTARTS   AGE
pod/scalable-nginx-854d4c7bb6-l5p6c   1/1     Running   0          2m57s
pod/scalable-nginx-854d4c7bb6-l9wfz   1/1     Running   0          2m57s

NAME                TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/nginx-web   ClusterIP   10.96.87.67   <none>        80/TCP    2m53s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/scalable-nginx   2/2     2            2           2m57s

NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/scalable-nginx-854d4c7bb6   2         2         2       2m57s
```

Finally you can access using your browser on http://127.0.0.1/ or can test using curl

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/
```

## clean up

To clean up you can remove using this

```bash
# To destroy
tofu destroy
```

or using docker

```bash
docker run -v ~/.aws:/root/.aws -v ~/.aws-sam:/root/.aws-sam -v ~/.docker:/root/.docker -v /var/run/docker.sock:/var/run/docker.sock -v ${PWD}:/opt/app -w /opt/app -v ~/.kube/config:/root/.kube/config -t -i --rm ghcr.io/opentofu/opentofu:latest destroy
```
