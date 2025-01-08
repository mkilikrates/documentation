# Deploy a GO application in a small Container

The goal of this example is to create a helm chart to deploy an web application `hello-app` write in [go](https://go.dev/) using a very small and safe container. To reduce the size and improve security by removing anything that is not needed in this case we are relying on [Google Distroless Images](https://github.com/GoogleContainerTools/distroless).

## Build Container

To build this container, execute from [Container](./Container/) folder:

```bash
docker build --provenance=false -t hello-app .
```

if you follow [steps](../../../kind/) to get a local registry in your cluster you can use

```bash
docker build --provenance=false -t localhost:5001/hello-app .
```

This is a simple example of a web hello-world that logs access.

### Test local

You can test local using

```bash
docker run --name myapp --rm -d -p 8080:8080 hello-app
```

or

```bash
docker run --name myapp --rm -d -p 8080:8080 localhost:5001/hello-app
```

*Note*: that we named our container to be easier to next steps

Finally you can access using your browser

* [hello](http://127.0.0.1:8080/)

To see logs use

```bash
docker logs myapp
```

To cancel it, use

```bash
docker stop myapp
```

### Publishing container image

#### Using local Registry

publish using

```bash
# if you need to tag
docker tag hello-app localhost:5001/hello-app
# publish/push
docker push localhost:5001/hello-app:latest
```

## Creating a new helm chart

To create a new chart

```bash
helm create helloapp
```

It will create a folder called `helloapp` and structure like this

```bash
.
├── Chart.yaml
├── charts
├── templates
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml
```

Since this is just a simple case, I will remove some files, like tests, serviceaccount and hpa, and add a new one called `secrets.yaml` so it can create a secret to use a private repository to get our container.

## View a helm chart

To view what this chart will create you can run from folder `gohello`

```bash
helm template ./helloapp
```

To lint you can use

```bash
helm lint ./helloapp
```

This will produce an output with all kubernetes manifests that will be applied with this chart.

## To install a helm chart

### from Local

To install this chart from local you can run from folder `gohello`

```bash
helm upgrade --install --debug -n helloapp --create-namespace \
 helloapp ./helloapp/
```

## clean up

To clean up you can remove using this

```bash
helm -n helloapp uninstall helloapp
kubectl delete namespaces helloapp
```
