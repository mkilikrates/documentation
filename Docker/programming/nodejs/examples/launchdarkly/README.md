# LaunchDarkly boolean flag

This is a simple example of how to use [LaunchDarkly](https://launchdarkly.com/) in a simple use case of boolean flag controlled on their [dashboard](https://app.launchdarkly.com/).

To create your account please follow instructions from their [page](https://app.launchdarkly.com/) selecting the option `Don't have an account?`.

The [official documentation](https://docs.launchdarkly.com/home/getting-started) can help you with more details.

## Executing the code

So, if you follow instructions and create your LaunchDarkly account, you will need both your SDK key and Flag key.

```bash
docker run --name node --user "$(id -u):$(id -g)" -t -i --rm -v "${PWD}":/usr/src -w /usr/src -p 3000:3000 -e LAUNCHDARKLY_SDK_KEY='sdk-0123456-789s4-123abc' -e LAUNCHDARKLY_FLAG_KEY='myflag' node:lts-slim /bin/bash
```

Inside of your docker, just run

```bash
npm install
node index.js
```

It will show something like this:

```bash
Server is running on port 3000
info: [LaunchDarkly] Opened LaunchDarkly stream connection
LaunchDarkly client initialized
```

*NOTE*: If your SDK Key is wrong, it will show authentication error on console log as well as in the Status message on page.

Finally you can access using your browser

* [hello](http://127.0.0.1:3000/)
* [Feature Flag](http://127.0.0.1:3000/feature-flag)

To cancel it, use `<CTRL>+<c>`

## Building your own container

In case you want to build a container ready to just run, there is this [Dockerfile](./Dockerfile) that you can use to build it.

You can find more information in [official documentation](https://docs.docker.com/reference/cli/docker/container/run/)

```bash
docker build . -t myapp
```

To run it

```bash
docker run -d --rm -p 3000:3000 -e LAUNCHDARKLY_SDK_KEY='sdk-0123456-789s4-123abc'  -e LAUNCHDARKLY_FLAG_KEY='myflag' myapp
```

Finally you can access using your browser

* [hello](http://127.0.0.1:3000/)
* [Feature Flag](http://127.0.0.1:3000/feature-flag)

you can see it running using

```bash
docker ps
```

It will show something like this:

```bash
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                    NAMES
3b7c360efc1f   myapp     "docker-entrypoint.s…"   36 seconds ago   Up 35 seconds   0.0.0.0:3000->3000/tcp   sleepy_brahmagupta
```

To see logs use

```bash
docker logs 3b7c360efc1f
```

*NOTE*: Since we didn't named our container, we must use their ID to interact with it

To cancel it, use

```bash
docker stop 3b7c360efc1f
```
