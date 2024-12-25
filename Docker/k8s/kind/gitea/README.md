# Using gitea as local git for testing purpose

Instead of creating multiple repositories in github, we can use [gitea](https://about.gitea.com/) as our git server inside of kubernetes cluster just for local testing.

## Table of Contents

- [Installation](#installation)
- [Clean up](#clean-up)

## Installation

[Official documentation an how to install](https://docs.gitea.com/installation/install-on-kubernetes)

In this example the installation will be executed using [helm](https://helm.sh/).

*Basic installation*: This will only install and expose it on host `http://gitea.local/` as http only, disabling https since this is a local test.

```bash
helm upgrade --install --namespace gitea --create-namespace \
 --repo https://dl.gitea.io/charts/ gitea gitea \
 --set service.http.type=LoadBalancer \
 --set ingress.enabled=true \
 --set ingress.className=nginx \
 --set ingress.hosts[0].host="gitea.local" \
 --set ingress.hosts[0].paths[0].path="/" \
 --set ingress.hosts[0].paths[0].pathType=Prefix \
 --set gitea.metrics.enabled=true \
 --set gitea.metrics.serviceMonitor.enabled=true \
 --set gitea.metrics.serviceMonitor.additionalLabels.release="prometheus-stack"
 ```

Note that latest 3 lines are to expose metrics to [prometheus operator](https://github.com/prometheus-operator/prometheus-operator?tab=readme-ov-file#helm-chart) so you can remove it if you don't need it.

Finally you can access using your browser

- [gitea](http://gitea.local/)

 or can test using curl

```bash
curl http://gitea.local/
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
```

This means, that I can have one configuration for my Github account and other for my local gitea, but you can have as much as you need, using same concepts. In both cases I want to store my credentials using *Github Credentials Manager* as I explained in [this](https://github.com/mkilikrates/documentation/tree/main/GCM)

so, my `~/gitea/.gitconfig`:

```bash
[user]
        name = gitea_admin
        email = gitea@local.domain
```

## clean up

To clean up you can remove using this

```bash
helm -n gitea uninstall gitea
kubectl delete namespaces gitea
```
