# Using Docker while developing or testing

Some simple use cases

## PYTHON

[Official documentation about this image](https://hub.docker.com/_/python)

Using local path where you are developing your code

```bash
docker run --name python -it --rm -v "${PWD}":/opt python /bin/bash
```

Executing a local script

```bash
docker run --name python -it --rm -v "${PWD}"::/usr/src/myapp -w /usr/src/myapp python python <script> <script-args>
```

## GROOVY

[Official documentation about this image](https://hub.docker.com/_/groovy)

Using local path where you are developing your code

```bash
docker run --name groovy -it --rm -v "${PWD}":/home/groovy/scripts -w /home/groovy/scripts groovy /bin/bash
```

Executing a local script

```bash
docker run --name groovy -it --rm -v "${PWD}":/home/groovy/scripts -w /home/groovy/scripts groovy groovy <script> <script-args>
```

## NODEJS

[Official documentation about this image](https://hub.docker.com/_/node)

Using local path where you are developing your code

```bash
docker run --name node --user "$(id -u):$(id -g)" -t -i --rm -v "${PWD}":/usr/src -w /usr/src node:slim /bin/bash
```

check some [simple case](./nodejs/) or other [examples](./nodejs/examples/)

## TYPESCRIPT

[Official documentation about this image](https://hub.docker.com/_/microsoft-devcontainers-typescript-node)

Using local path where you are developing your code

```bash
docker run --user "$(id -u)":"$(id -g)" -it --rm -v ${PWD}:/home/node/app -w /home/node/app  mcr.microsoft.com/devcontainers/typescript-node /bin/bash
```

## GO

[Official documentation about this image](https://hub.docker.com/_/golang)

check some [simple case](./go/)

Using local path where you are developing your code

```bash
docker run -it --rm -v ${PWD}:/usr/src/myapp -w /usr/src/myapp  golang /bin/bash
```

Executing a local script

```bash
docker run -it --rm -v ${PWD}:/usr/src/myapp -w /usr/src/myapp -p 8080:8080  golang go run .
```

Compiling a local script to make it executable

```bash
docker run -it --rm -v ${PWD}:/usr/src/myapp -w /usr/src/myapp -p 8080:8080 -e CGO_ENABLED=0 -e GOOS=linux -e GOARCH=amd64 golang go build -o ./app .
```
