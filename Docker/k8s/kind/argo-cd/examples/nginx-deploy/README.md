# Deploying a nginx

This will deploy 1 [pod](https://kubernetes.io/docs/concepts/workloads/pods/) and [service](https://kubernetes.io/docs/concepts/services-networking/service/)/[ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) on [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) `argo-simple-nginx`

## nginx

[Official documentation about this image](https://hub.docker.com/_/nginx)

## Using gitea as Local git repository provider

For the purpose of testing and making changes in this deployment, please follow steps on [this link](../../../gitea/README.md) to install gitea, then steps bellow to create a new repository

```bash
# create a folder
mkdir ngix_deploy
# initiate as git repo
git init
# create a Deployment file
mkdir development
echo 'apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx-container
        image: nginx:latest
' > development/Deployment.yaml
# add file to git
git add -A
git commit -m "my first commit"
# set upstream git to gitea and push/creating new repo
git remote add origin http://gitea.local/gitea_admin/ngix_deploy.git
git push -o repo.private=false --set-upstream origin main
```

## argo-cd manifest

Now, let's apply our argo application manifest

*Note*: Instead of targeting our ingress we are targeting the gitea service directly on `repoURL` in our [argo-nginx.yaml](argo-nginx.yaml) file.

```bash
kubectl apply -f argo-nginx.yaml
```

Now you can see our deployment on [argo](http://127.0.0.1/argo-cd/applications)

or you can check using cli

```bash
kubectl -n nginx-deploy get all
```

It will show something like this:

```bash
NAME                                  READY   STATUS    RESTARTS   AGE
pod/nginx-deploy-1-58cdc7b878-vx986   1/1     Running   0          21s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deploy-1   1/1     1            1           21s

NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deploy-1-58cdc7b878   1         1         1       21s
```

Now you can for instance change the number of replicas from 1 to 2 or any other change in your repo

check like this

```bash
git diff
```

It will show something like this:

```bash
diff --git a/development/Deployment.yaml b/development/Deployment.yaml
index ef99a4c..7979fff 100644
--- a/development/Deployment.yaml
+++ b/development/Deployment.yaml
@@ -5,7 +5,7 @@ metadata:
   labels:
     app: nginx
 spec:
-  replicas: 1
+  replicas: 2
   selector:
     matchLabels:
       app: nginx
```

then you commit it

```bash
git add -A
git commit -m "my second commit"
git push
```

If you kept the argocd opened, you will note that in few seconds, it will detect that change and automatically apply in your cluster.

or, you can check again

```bash
kubectl -n nginx-deploy get all
```

It will show something like this:

```bash
NAME                                  READY   STATUS    RESTARTS   AGE
pod/nginx-deploy-1-58cdc7b878-ckchl   1/1     Running   0          89s
pod/nginx-deploy-1-58cdc7b878-vx986   1/1     Running   0          11m

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deploy-1   2/2     2            2           11m

NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deploy-1-58cdc7b878   2         2         2       11m
```

## clean up

To clean up you can remove using this

```bash
kubectl delete -f argo-nginx.yaml
# in case you not delete your repo
kubectl delete namespaces nginx-deploy
```
