# Using Docker with other tools

Some simple use tools

## Table of Contents

- [AWS CLI](#aws-cli)
- [AWS SAM](#aws-sam)
- [AWS CDK](#aws-cdk-python)
- [AWS CDK + SAM](#aws-cdk--sam)
- [AWS SAM + CDK + CDK8s + TERRAFORM + CDKTF](#aws-sam--cdk--cdk8s--terraform--cdktf)
- [Terraform & OpenTofu](#terraform-or-opentofu-cli)
- [Kubectl](#kubectl)
- [EKS](#aws-eks-kubectl--helm--iam-authenticator--kconnect)
- [Credentials](#credentials)

## AWS CLI

[Official documentation about this image](https://hub.docker.com/r/amazon/aws-cli)

Using local path where your credentials are stored

```bash
docker run --rm -ti -v ~/.aws:/root/.aws -v $(pwd):/aws amazon/aws-cli <service> <command> <args>
```

e.g.:

```bash
docker run --rm -ti -v ~/.aws:/root/.aws -v $(pwd):/aws amazon/aws-cli s3 ls
```

**PS:**
this docker will run using root inside of container, so if you configure your credentials using it, your local user if not root will not able to see files in `~/.aws/`

Add this alias to your ~/.bash_aliases so you can use allways this docker instead of install anything local

```bash
alias aws='docker run --rm -ti -v ~/.aws:/root/.aws -v $(pwd):/aws amazon/aws-cli'
```

If you just edit your file, run the following command to reload your environment

```bash
source ~/.bashrc
```

Then you can run any command

```bash
aws --version
```

## AWS SAM

[Official documentation about sam](https://docs.aws.amazon.com/serverless-application-model/)

There is no official image for these tools, in this case I sharing a [dockerfile](./Docker/sam-pythonSlimDinD.dockerfile) and following instructions to build and run.

**OBS:** Due [incompatibility issues with Alpine](https://github.com/aws/aws-sam-cli/issues/4221), I decide to base this image on python3-slim

This image rely on [Docker-in-Docker](https://hub.docker.com/_/docker)

When build this image, you can pass your username as argument or leave as `cdk`.

Building as default user `sam`:

```bash
docker build -t sam - < sam-pythonSlimDinD.dockerfile
```

Building as your user, using OS variable `$USER` or change it for the user you want:

```bash
docker build -t sam --build-arg USER_NAME="$USER" --build-arg GROUP_ID=$(getent group docker | cut -d: -f3) - < sam-pythonSlimDinD.dockerfile
```

Using local path where your credentials are stored, current folder for your code and giving docker permission (D-in-D)

using default user `sam`

```bash
docker run --user sam:$(getent group docker | cut -d: -f3) --privileged -e SAM_CLI_TELEMETRY=0 -e AWS_EC2_METADATA_DISABLED="true" -v ${PWD}:/opt/app -v ~/.aws:/home/sam/.aws -v ~/.aws-sam:/home/sam/.aws-sam -v ~/.docker:/home/sam/.docker -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD":/opt/app --rm -t -i sam
```

using local user `$USER`

```bash
docker run --user $(id -u):$(getent group docker | cut -d: -f3) --privileged -e SAM_CLI_TELEMETRY=0 -e AWS_EC2_METADATA_DISABLED="true" -v ${PWD}:/opt/app -v ~/.aws/:/home/$USER/.aws/ -v ~/.aws-sam/:/home/$USER/.aws-sam/ -v ~/.docker/:/home/$USER/.docker/ -v /var/run/docker.sock:/var/run/docker.sock --rm sam sam
```

After inside of docker, you can for instance follow the [CDK for python documentation](https://docs.aws.amazon.com/cdk/v2/guide/work-with-cdk-python.html)

```bash
cdk init app --language python
source .venv/bin/activate
python -m pip install -r requirements.txt
```

## AWS CDK (python)

[Official documentation about cdk](https://aws.amazon.com/cdk/)

There is no official image for these tools, in this case I sharing a [dockerfile](./Docker/cdk-alpineDinD.dockerfile) and following instructions to build and run.

This image rely on [Docker-in-Docker](https://hub.docker.com/_/docker)

When build this image, you can pass your username as argument or leave as `cdk`.

Building as default user `cdk`:

```bash
docker build -t cdk-py3 - < pythonSlimDinD.dockerfile
```

Building as your user, using OS variable `$USER` or change it for the user you want:

```bash
docker build -t cdk-py3 --build-arg USER_NAME="$USER" - < pythonSlimDinD.dockerfile
```

Using local path where your credentials are stored, current folder for your code and giving docker permission (D-in-D)

using default user `cdk`

```bash
docker run --name cdk-py3 --user cdk:$(getent group docker | cut -d: -f3) --privileged -v ${PWD}:/opt/app -v ~/.aws:/home/cdk/.aws -v ~/.aws-sam:/home/$USER/.aws-sam -v ~/.docker:/home/cdk/.docker -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD":/app -t -i --rm cdk-py3
```

using local user `$USER`

```bash
docker run --name cdk-py3 --user $(id -u):$(getent group docker | cut -d: -f3) --privileged -v ${PWD}:/opt/app -v ~/.aws:/home/cdk/.aws -v ~/.aws-sam:/home/cdk/.aws-sam -v ~/.docker:/home/cdk/.docker -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD":/opt/app -t -i --rm cdk-py3
```

After inside of docker, you can for instance follow the [CDK for python documentation](https://docs.aws.amazon.com/cdk/v2/guide/work-with-cdk-python.html)

```bash
cdk init app --language python
source .venv/bin/activate
python -m pip install -r requirements.txt
```

## AWS CDK + SAM

[Official documentation about cdk](https://aws.amazon.com/cdk/)

[Official documentation about sam](https://docs.aws.amazon.com/serverless-application-model/)

[Better together](https://aws.amazon.com/blogs/compute/better-together-aws-sam-and-aws-cdk/)

There is no official image for these tools, in this case I sharing a [dockerfile](./Docker/sam-cdk-pythonSlimDinD.dockerfile) and following instructions to build and run.

**OBS:** Due [incompatibility issues with Alpine](https://github.com/aws/aws-sam-cli/issues/4221), I decide to base this image on python3-slim

This image rely on [Docker-in-Docker](https://hub.docker.com/_/docker)

When build this image, you can pass your username as argument or leave as `cdk`.

Building as default user `cdk`:

```bash
docker build -t sam-cdk - < sam-cdk-pythonSlimDinD.dockerfile
```

Building as your user, using OS variable `$USER` or change it for the user you want:

```bash
docker build -t sam-cdk --build-arg USER_NAME="$USER" --build-arg GROUP_ID=$(getent group docker | cut -d: -f3) - < sam-cdk-pythonSlimDinD.dockerfile
```

There are other arguments that can be set using build-arg option to set the version of what is installing:

- NVM_VERSION
- AWS_SAM_VERSION
- AWS_CDK_VERSION
- AWS_CDK8S_VERSION

Using local path where your credentials are stored, current folder for your code and giving docker permission (D-in-D)

using default user `cdk`

```bash
docker run --user $(id -u):$(getent group docker | cut -d: -f3) --privileged -v ${PWD}:/opt/app -v ~/.aws:/home/cdk/.aws -v ~/.aws-sam:/home/cdk/.aws-sam -v ~/.docker:/home/cdk/.docker -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD":/opt/app -t -i --rm sam-cdk
```

using local user `$USER`

```bash
docker run --user cdk:$(getent group docker | cut -d: -f3) --privileged -v ${PWD}:/opt/app -v ~/.aws:/home/cdk/.aws -v ~/.aws-sam:/home/$USER/.aws-sam -v ~/.docker:/home/cdk/.docker -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD":/opt/app -t -i --rm sam-cdk
```

After inside of docker, you can for instance follow the [CDK for python documentation](https://docs.aws.amazon.com/cdk/v2/guide/work-with-cdk-python.html)

```bash
cdk init app --language python
source .venv/bin/activate
python -m pip install -r requirements.txt
```

## AWS SAM + CDK + CDK8s + TERRAFORM + CDKTF + KUBECTL + Kconnect

[Official documentation about cdk](https://aws.amazon.com/cdk/)

[Official documentation about sam](https://docs.aws.amazon.com/serverless-application-model/)

[Official documentation about CDK8S](https://cdk8s.io/)

[Official documentation about TERRAFORM](https://www.terraform.io/)

[Official documentation about CDKFT](https://developer.hashicorp.com/terraform/tutorials/cdktf)

[Official documentation about kubectl](https://hub.docker.com/r/bitnami/kubectl/)

There is no official image for these tools, in this case I sharing a [dockerfile](./Docker/sam-cdk-pythonSlimDinD.dockerfile) and following instructions to build and run.

**OBS:** Due [incompatibility issues with Alpine](https://github.com/aws/aws-sam-cli/issues/4221), I decide to base this image on python3-slim

This image rely on [Docker-in-Docker](https://hub.docker.com/_/docker)

When build this image, you can pass your username as argument or leave as `cdk`.

Building as default user `cdk`:

```bash
docker build -t sam-cdk-tf - < sam-cdk-tf-pythonSlimDinD.dockerfile
```

Building as your user, using OS variable `$USER` or change it for the user you want:

```bash
docker build -t sam-cdk-tf --build-arg USER_NAME="$USER" --build-arg GROUP_ID=$(getent group docker | cut -d: -f3) - < sam-cdk-tf-pythonSlimDinD.dockerfile
```

There are other arguments that can be set using build-arg option to set the version of what is installing:

- NVM_VERSION
- AWS_SAM_VERSION
- AWS_CDK_VERSION
- AWS_CDK8S_VERSION
- AWS_CDKTF_VERSION

Using local path where your credentials are stored, current folder for your code and giving docker permission (D-in-D)

using default user `cdk`

```bash
docker run --user $(id -u):$(getent group docker | cut -d: -f3) --privileged -e SAM_CLI_TELEMETRY=0 -e AWS_EC2_METADATA_DISABLED="true" -v "${PWD}":/opt/app -v ~/.aws/:/home/cdk/.aws/ -v ~/.aws-sam/:/home/cdk/.aws-sam/ -v ~/.docker/:/home/cdk/.docker/ -v /var/run/docker.sock:/var/run/docker.sock -v "$HOME"/.kube:/home/cdk/.kube -v "$HOME"/.helm:/home/cdk/.helm -v "$HOME"/.config/helm:/home/cdk/.config/helm -v "$HOME/.kconnect:/home/cdk/.kconnect/" -v "$HOME"/.terraform.d:/home/cdk/.terraform.d -v "$HOME"/lixo:/home/cdk/tmp --rm sam-cdk-tf
```

*Note*: I have this container build available on my github registry, so if you want to use it you can just

```bash
docker run --user $(id -u):$(getent group docker | cut -d: -f3) --privileged -e SAM_CLI_TELEMETRY=0 -e AWS_EC2_METADATA_DISABLED="true" -v "${PWD}":/opt/app -v ~/.aws/:/home/cdk/.aws/ -v ~/.aws-sam/:/home/cdk/.aws-sam/ -v ~/.docker/:/home/cdk/.docker/ -v /var/run/docker.sock:/var/run/docker.sock -v "$HOME"/.kube:/home/cdk/.kube -v "$HOME"/.helm:/home/cdk/.helm -v "$HOME"/.config/helm:/home/cdk/.config/helm -v "$HOME/.kconnect:/home/cdk/.kconnect/" -v "$HOME"/.terraform.d:/home/cdk/.terraform.d -v "$HOME"/lixo:/home/cdk/tmp --rm ghcr.io/mkilikrates/sam-cdk-tf:latest
```

using local user `$USER`

```bash
docker run --user $(id -u):$(getent group docker | cut -d: -f3) --privileged -e SAM_CLI_TELEMETRY=0 -e AWS_EC2_METADATA_DISABLED="true" -v "${PWD}":/opt/app -v ~/.aws/:/home/$USER/.aws/ -v ~/.aws-sam/:/home/$USER/.aws-sam/ -v ~/.docker/:/home/$USER/.docker/ -v /var/run/docker.sock:/var/run/docker.sock -v "$HOME"/.kube:/home/$USER/.kube -v "$HOME"/.helm:/home/$USER/.helm -v "$HOME"/.config/helm:/home/$USER/.config/helm -v "$HOME/.kconnect:/home/$USER/.kconnect/" -v "$HOME"/.terraform.d:/home/$USER/.terraform.d -v "$HOME"/lixo:/home/$USER/tmp --rm sam-cdk-tf
```

Since CDK, CDK8s and CDKTF relies on pipenv, you should install the dependencies in projects alredy existent:

```bash
pipenv sync
```

or

```bash
pipenv install -r requirements.txt
```

Then follow the documentation from each tool to synth, deploy, destroy your stack.

- [CDK for python documentation](https://docs.aws.amazon.com/cdk/v2/guide/work-with-cdk-python.html)
- [CDK8S for python documentation](https://cdk8s.io/docs/latest/getting-started/#prerequisites)
- [CDKTF for python documentation](https://developer.hashicorp.com/terraform/tutorials/cdktf/cdktf-install?variants=cdk-language%3Apython)

## Terraform or OpenTofu CLI

### terraform

[Official documentation about this image](https://hub.docker.com/r/hashicorp/terraform)

### opentofu

[Official documentation about this image](https://opentofu.org/docs/intro/install/docker/)

*Note*: You can change from terraform to opentofu replacing the image from `hashicorp/terraform:latest` to `ghcr.io/opentofu/opentofu:latest`.

Using local path as workspace

```bash
docker run -t -i --rm -v "${PWD}":/workspace -w /workspace hashicorp/terraform:latest <command> <args>
```

e.g.:

```bash
docker run -t -i --rm -v "${PWD}":/workspace -w /workspace hashicorp/terraform:latest apply
```

Additionally, depends on your use case, you can mount your credentials files for cloud or kubernetes and even work as docker-in-docker to build containers like this:

```bash
docker run -t -i --rm -v "${HOME}"/.aws:/root/.aws -v ~/.kube/config:/root/.kube/config -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}":/workspace -w /workspace ghcr.io/opentofu/opentofu:latest
```

**PS:**
this docker will run using root inside of container, so if you configure your credentials using it, your local user if not root will not able to see files in `~/.aws/`

Add this alias to your ~/.bash_aliases so you can use allways this docker instead of install anything local

```bash
alias terraform='docker run -t -i --rm -v "${HOME}"/.aws:/root/.aws -v ~/.kube/config:/root/.kube/config -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}":/workspace -w /workspace hashicorp/terraform:latest'
alias tofu='docker run -t -i --rm -v "${HOME}"/.aws:/root/.aws -v ~/.kube/config:/root/.kube/config -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}":/workspace -w /workspace ghcr.io/opentofu/opentofu:latest'
```

If you just edit your file, run the following command to reload your environment

```bash
source ~/.bashrc
```

Then you can run any command

```bash
terraform --version
tofu --version
```

## Kubectl

[Official documentation about this image](https://hub.docker.com/r/bitnami/kubectl/)

Using local path where your credentials are stored

```bash
docker run --user "$(id -u)":"$(id -g)" --rm -ti -v ~/.kube/config:/.kube/config bitnami/kubectl:latest <command> <args>
```

Add this alias to your ~/.bash_aliases so you can use allways this docker instead of install anything local

```bash
alias kubectl='docker run --user "$(id -u)":"$(id -g)" --rm -ti -v ~/.kube/config:/.kube/config bitnami/kubectl:latest'
```

If you just edit your file, run the following command to reload your environment

```bash
source ~/.bashrc
```

Then you can run any command

```bash
kubectl version
```

## AWS EKS (kubectl + helm + iam-authenticator + kconnect)

There is no official image for these tools, in this case I sharing a [dockerfile](./Docker/eks.Dockerfile) and following instructions to build and run.

When build this image, you can pass your username as argument or leave as `eks`.

Building as default user `eks`:

```bash
docker build -t eks - < eks.Dockerfile
```

Building as your user, using OS variable `$USER` or change it for the user you want:

```bash
docker build -t eks --build-arg USER_NAME="$USER" --build-arg GROUP_ID=$(id -g) - < eks.Dockerfile
```

Using local path where your credentials are stored, current folder for your code and giving docker permission (D-in-D)

using default user `eks`

```bash
docker run --user "1000:1000" -it --rm -v "$HOME/.aws:/home/eks/.aws/" -v "${PWD}":/opt/app -w /opt/app -v "$HOME"/.kube:/home/eks/.kube -v "$HOME"/.helm:/home/eks/.helm -v "$HOME"/.config/helm:/home/eks/.config/helm -v "$HOME"/.cache/helm:/home/eks/.cache/helm -v "$HOME/.kconnect:/home/eks/.kconnect/" eks:latest
```

using local user `$USER`

```bash
docker run --user "$(id -u)":"$(id -g)" -it --rm -v "$HOME/.aws:/home/$USER/.aws/" -v "${PWD}":/opt/app -w /opt/app -v "$HOME"/.kube:/home/$USER/.kube -v "$HOME"/.helm:/home/$USER/.helm -v "$HOME"/.config/helm:/home/$USER/.config/helm -v "$HOME"/.cache/helm:/home/$USER/.cache/helm -v "$HOME/.kconnect:/home/$USER/.kconnect/" eks:latest
```

After inside of docker, you can for instance follow the [CDK for python documentation](https://docs.aws.amazon.com/cdk/v2/guide/work-with-cdk-python.html)

```bash
cdk init app --language python
source .venv/bin/activate
python -m pip install -r requirements.txt
```

## Credentials

If you need to pass credentials in order to build image. For instance authenticating against a corporate proxy.

In your Dockerfile:

```Dockerfile
# Install aws sam
RUN --mount=type=secret,id=PASSWORD,dst=/run/secrets/.creds \
    PASSWORD=$(cat /run/secrets/.creds) && \
    curl -kx http://http.proxy.example.com:3128 -U "${SAM_USER}:$PASSWORD" -L -O https://github.com/aws/aws-sam-cli/releases/${AWS_SAM_VERSION}/download/aws-sam-cli-linux-x86_64.zip && \
    unzip aws-sam-cli-linux-x86_64.zip -d sam-installation && \
    ./sam-installation/install --update && \
    rm -rf sam-installation/ && \
    rm -rf aws-sam-cli-linux-x86_64.zip
```

Then you can build using [builkit secrets](https://docs.docker.com/engine/swarm/secrets/)

```bash
export CREDS="<MY_ PASSWORD>";DOCKER_BUILDKIT=1;docker build -t eks --build-arg USER_NAME="$USER" --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(getent group docker | cut -d: -f3) --secret id=PASSWORD,env=CREDS - <eks.Dockerfile;unset CREDS
```
