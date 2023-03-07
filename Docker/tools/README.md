# Using Docker with other tools

Some simple use cases

## AWS CDK

[Official documentation about this image](https://hub.docker.com/r/amazon/aws-cli)

Using local path where your credentials are stored

```bash
docker run --rm -ti -v ~/.aws:/root/.aws -v $(pwd):/aws amazon/aws-cli <service> <command> <args>
```

e.g.:

```bash
docker run --rm -ti -v ~/.aws:/root/.aws -v $(pwd):/aws amazon/aws-cli s3 ls
```

* PS:
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
