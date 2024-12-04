# Deploying a simple nginx

This will deploy 2 nginx [pod](https://kubernetes.io/docs/concepts/workloads/pods/) in a [service](https://kubernetes.io/docs/concepts/services-networking/service/)/[ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) on [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) `scalable-nginx` set on variable file [terraform.tfvars](terraform.tfvars)

## nginx

[Official documentation about this image](https://hub.docker.com/_/nginx)

## terraform

[Official documentation about this image](https://hub.docker.com/r/hashicorp/terraform)

To deploy a this using [kubernetes.tf](kubernetes.tf)

```bash
# To initialize
terraform init
# To check what will be applied
terraform plan
# To deploy
terraform apply
```

Instead of [install terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) you can use their docker as bellow:

```bash
docker run -v ${PWD}:/opt/app -w /opt/app -v ~/.kube/config:/root/.kube/config -t -i --rm hashicorp/terraform:latest <command> <options>
```

*Note*: Since in my configuration I want to use credentials from my local WSL, it is being mounted with '-v', details can be found on [Docker documentation](https://docs.docker.com/engine/storage/bind-mounts/)

*Steps documentation*:
- [init](https://developer.hashicorp.com/terraform/cli/commands/init)
- [plan](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [apply](https://developer.hashicorp.com/terraform/tutorials/cli/apply)

You can check that it is running using

```bash
kubectl -n scalable-nginx get all
```

It will show something like this:

```bash
NAME                                  READY   STATUS    RESTARTS   AGE
pod/scalable-nginx-854d4c7bb6-kwt4q   1/1     Running   0          5m53s
pod/scalable-nginx-854d4c7bb6-l4x4c   1/1     Running   0          5m53s

NAME                TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/nginx-web   ClusterIP   10.96.96.89   <none>        80/TCP    5m49s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/scalable-nginx   2/2     2            2           5m53s

NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/scalable-nginx-854d4c7bb6   2         2         2       5m53s
```

Finally you can access using your browser on http://127.0.0.1/ or can test using curl

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/
```

## clean up

To clean up you can remove using this

```bash
# To destroy
terraform destroy
```

or using docker

```bash
docker run -v ~/.aws:/root/.aws -v ~/.aws-sam:/root/.aws-sam -v ~/.docker:/root/.docker -v /var/run/docker.sock:/var/run/docker.sock -v ${PWD}:/opt/app -w /opt/app -v ~/.kube/config:/root/.kube/config -t -i --rm hashicorp/terraform:latest destroy
```
