# Using Docker with other tools

Some simple use tools

## Table of Contents

- [AWS CLI](#aws-cli)
- [AWS CDK + SAM](#aws-cdk--sam)
- [Kubectl](#kubectl)

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
docker run --name cdk-py3 --user $(id -u):$(getent group docker | cut -d: -f3) --privileged -v ${PWD}:/opt/app -v ~/.aws:/home/cdk/.aws -v ~/.aws-sam:/home/cdk/.aws-sam -v ~/.docker:/home/cdk/.docker -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD":/opt/app -t -i --rm cdk-py3
```

using local user `$USER`

```bash
docker run --name cdk-py3 --user cdk:$(getent group docker | cut -d: -f3) --privileged -v ${PWD}:/opt/app -v ~/.aws:/home/cdk/.aws -v ~/.aws-sam:/home/$USER/.aws-sam -v ~/.docker:/home/cdk/.docker -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD":/app -t -i --rm cdk-py3
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

There is no official image for these tools, in this case I sharing a [dockerfile](./Docker/pythonSlimDinD.dockerfile) and following instructions to build and run.

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
docker run --name cdk-py3 --user cdk:$(getent group docker | cut -d: -f3) --privileged -v ${PWD}:/opt/app -v ~/.aws:/home/cdk/.aws -v ~/.aws-sam:/home/$USER/.aws-sam -v ~/.docker:/home/cdk/.docker -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD":/opt/app -t -i --rm cdk-py3
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

## AWS SAM + EKS (kubectl + helm + iam-authenticator + kconnect)

[Official documentation about sam](https://docs.aws.amazon.com/serverless-application-model/)

There is no official image for these tools, in this case I sharing a [dockerfile](./Docker/sam-eks.Dockerfile) and following instructions to build and run.

This image rely on [Docker-in-Docker](https://hub.docker.com/_/docker)

When build this image, you can pass your username as argument or leave as `cdk`.

Building as default user `sam`:

```bash
docker build -t sam-eks - < sam-eks.Dockerfile
```

Building as your user, using OS variable `$USER` or change it for the user you want:

```bash
docker build -t sam-eks --build-arg USER_NAME="$USER" - < sam-eks.Dockerfile
```

Using local path where your credentials are stored, current folder for your code and giving docker permission (D-in-D)

using default user `sam`

```bash
docker run --user sam:$(getent group docker | cut -d: -f3) --privileged -v ${PWD}:/opt/app -v ~/.aws:/home/cdk/.aws -v ~/.aws-sam:/home/$USER/.aws-sam -v ~/.docker:/home/cdk/.docker -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD":/opt/app -t -i --rm cdk-py3
```

using local user `$USER`

```bash
docker run --user $(id -u):$(getent group docker | cut -d: -f3) --privileged -v ${PWD}:/opt/app -v ~/.aws:/home/cdk/.aws -v ~/.aws-sam:/home/cdk/.aws-sam -v ~/.docker:/home/cdk/.docker -v /var/run/docker.sock:/var/run/docker.sock -v ~/. -v "$PWD":/opt/app -t -i --rm cdk-py3
```

After inside of docker, you can for instance follow the [CDK for python documentation](https://docs.aws.amazon.com/cdk/v2/guide/work-with-cdk-python.html)

```bash
cdk init app --language python
source .venv/bin/activate
python -m pip install -r requirements.txt
```
