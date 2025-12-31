# Using gitea as local git for testing purpose

Instead of creating multiple repositories in github, we can use [gitea](https://about.gitea.com/) as our git server inside of kubernetes cluster just for local testing.

## Table of Contents

- [Installation](#installation)
- [Clean up](#clean-up)

## Installation

[Official documentation an how to install](https://docs.gitea.com/installation/install-on-kubernetes)

In this example the installation will be executed using [helm](https://helm.sh/).

*Basic installation*: This will only install and expose it on host `https://host.docker.internal/gitea` without any HA.

```bash
helm repo add gitea https://dl.gitea.io/charts/
helm repo update
helm upgrade --install gitea gitea/gitea \
 --namespace gitea --create-namespace \
 --set gitea.config.repository.ENABLE_PUSH_CREATE_USER=true \
 --set gitea.config.repository.ENABLE_PUSH_CREATE_ORG=true \
 --set gitea.config.server.ROOT_URL=https://host.docker.internal/gitea/ \
 --set gitea.config.server.DISABLE_SSH=true \
 --set gitea.config.server.LFS_START_SERVER=true \
 --set gitea.config.packages.ENABLED=true \
 --set redis-cluster.enabled=false \
 --set redis.enabled=true \
 --set postgresql-ha.enabled=false \
 --set postgresql.enabled=true \
 --set service.http.type=LoadBalancer \
 --set ingress.enabled=true \
 --set ingress.className=nginx \
 --set ingress.annotations."nginx\.ingress\.kubernetes\.io/use-regex"=true \
 --set ingress.annotations."nginx\.ingress\.kubernetes\.io/rewrite-target"=/\$3 \
 --set ingress.annotations."nginx\.ingress\.kubernetes\.io/proxy-body-size"=512m \
 --set ingress.hosts[0].host="host.docker.internal" \
 --set ingress.hosts[0].paths[0].path="/(gitea|v2)($|/)?(.*)" \
 --set ingress.hosts[0].paths[0].pathType=ImplementationSpecific \
 --set ingress.tls[0].hosts[0]="host.docker.internal" \
 --set gitea.metrics.enabled=true \
 --set gitea.metrics.serviceMonitor.enabled=true \
 --set gitea.metrics.serviceMonitor.additionalLabels.release="prometheus-stack"
 ```

Note that latest 3 lines are to expose metrics to [prometheus operator](https://github.com/prometheus-operator/prometheus-operator?tab=readme-ov-file#helm-chart) so you can remove it if you don't need it.
Additionally, it is allowing create new repositories using simple git push.

Finally you can access using your browser

- [gitea](https://host.docker.internal/gitea)

 or can test using curl

```bash
curl -k https://host.docker.internal/gitea
```

*PS*: In this example we are using the default credentials from [values.yaml](https://gitea.com/gitea/helm-chart/src/branch/main/values.yaml#L456), so if you want to set your own local credentials you can add this

```bash
 --set gitea.admin.username="my_username" \
 --set gitea.admin.password="my_password" \
 --set gitea.admin.email="my_email@example.com"
```

If you are using prometheus, you can import some dashboard from [grafana](https://grafana.com/grafana/dashboards/?search=gitea)

## Setup gitconfig for multiple repositories

You can setup your local git environment to support multiple providers based on your folder.

*Based on WSL*: Using a Windows with WSL2 as example

file `~/.gitconfig`

```bash
[credential]
        helper = /usr/local/bin/git-credential-manager
        credentialStore = gpg
[init]
        defaultBranch = main
[includeIf "gitdir:~/github/"]
    path = ~/github/.gitconfig
[includeIf "gitdir:~/gitea/"]
    path = ~/gitea/.gitconfig
[credential "https://host.docker.internal"]
        provider = generic
[http "https://host.docker.internal"]
        sslVerify = false
```

This means, that I can have one configuration for my Github account and other for my local gitea, but you can have as much as you need, using same concepts. In both cases I want to store my credentials using *Github Credentials Manager* as I explained in [this](https://github.com/mkilikrates/documentation/tree/main/GCM)

so, my `~/gitea/.gitconfig`:

```bash
[user]
        name = gitea_admin
        email = gitea@local.domain
```

## Create a simple repo

```bash
# create a folder
mkdir my_first_repo
cd my_first_repo/
#initiate git
git init
# create a file with content
echo "This is my first_repo! " > README.md
# add this file to my git
git add README.md
git commit -m "my first commit"
# set upstream git to gitea and push/creating new repo
git remote add origin https://host.docker.internal/gitea/gitea_admin/my_first_repo.git
git -c http.sslVerify=false push -o repo.private=false --set-upstream origin main
```

Finally you can access using your browser

- [gitea](https://host.docker.internal/gitea/gitea_admin/my_first_repo)

## clean up

To clean up you can remove using this

```bash
helm -n gitea uninstall gitea
kubectl delete namespaces gitea
```
