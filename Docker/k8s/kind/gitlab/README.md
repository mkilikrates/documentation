# Using gitlab as local git for testing purpose

Instead of creating multiple repositories in github, we can use [gitlab](https://about.gitlab.com/) as our git server inside of kubernetes cluster just for local testing.

## Table of Contents

- [Installation](#installation)
- [Clean up](#clean-up)

## Installation

[Official documentation an how to install](https://docs.gitlab.com/charts/installation/deployment.html)

In this example the installation will be executed using [helm](https://helm.sh/).

*Basic installation*: This will only install and expose it on host `https://gitlab.<Your-IP>.io` without any HA.

```bash
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm upgrade --install --namespace gitlab --create-namespace \
 --timeout 15m gitlab gitlab/gitlab \
 --set global.edition=ce \
 --set global.hosts.domain="$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}').nip.io" \
 --set global.hosts.externalIP="$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')" \
 --set global.ingress.configureCertmanager=false \
 --set global.ingress.class=nginx \
 --set global.minio.enabled=true \
 --set certmanager.install=false \
 --set nginx-ingress.enabled=false \
 --set prometheus.install=false \
 --set gitlab.gitlab-shell.minReplicas=1 \
 --set gitlab.gitlab-shell.maxReplicas=1 \
 --set gitlab.gitlab-exporter.enabled=true \
 --set gitlab.webservice.minReplicas=1 \
 --set gitlab.webservice.maxReplicas=1 \
 --set gitlab.sidekiq.minReplicas=1 \
 --set gitlab.sidekiq.maxReplicas=1 \
 --set gitlab.gitaly.resources.requests.cpu=50m \
 --set gitlab.shared-secrets.resources.requests.cpu=10m \
 --set gitlab.migrations.resources.requests.cpu=10m \
 --set gitlab.toolbox.resources.requests.cpu=10m \
 --set registry.hpa.minReplicas=1 \
 --set registry.hpa.maxReplicas=1 \
 --set redis.metrics.resources.requests.cpu=10m \
 --set postgresql.metrics.resources.requests.cpu=10m
 ```

Finally you can access using your browser

- [gitlab](https://gitlab.<Your-IP>.io)

 or can test using curl like

```bash
curl -k curl -k https://gitlab.192.168.1.104.nip.io/
```

to get the default password you can use

```bash
kubectl -n gitlab get secrets gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 -d;echo
```

If you are using prometheus, you can import some dashboard from [grafana](https://grafana.com/grafana/dashboards/?search=gitlab)

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
[includeIf "gitdir:~/gitlab/"]
    path = ~/gitlab/.gitconfig
```

This means, that I can have one configuration for my Github account and other for my local gitlab, but you can have as much as you need, using same concepts. In both cases I want to store my credentials using *Github Credentials Manager* as I explained in [this](https://github.com/mkilikrates/documentation/tree/main/GCM)

so, my `~/gitlab/.gitconfig`:

```bash
[user]
        name = root
        email = root@local.domain
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
# set upstream git to gitlab and push/creating new repo
git remote add origin https://gitlab.$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}').nip.io/root/my_first_repo.git
git -c http.sslVerify=false push -o repo.private=false --set-upstream origin main
```

Finally you can access using your browser

- [gitlab](https://gitlab.<Your-IP>.io/root/my_first_repo)

## clean up

To clean up you can remove using this

```bash
helm -n gitlab uninstall gitlab
kubectl delete namespaces gitlab
```
