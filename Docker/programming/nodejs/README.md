# Using Nodejs on docker

This way, you don't need to install anything local as well as you can easialy change between different version as you need.

## Getting Start with Hello World

As I explained [earlier](../../programming/), we can use a docker to start a new code, in our case, let's assume we will export a web service to your local host on port `3000`, so we will use this:

```bash
mkdir my_app
cd my_app
docker run --name node --user "$(id -u):$(id -g)" -t -i --rm -v "${PWD}":/usr/src -w /usr/src -p 3000:3000 node:lts-slim /bin/bash
```

*NOTE*: in this case we are selecting the `long term support` version since our image tag is `node:lts-slim`. Check other tags in [DockerHub](https://hub.docker.com/_/node).

### Initilize a new node project

Now, we are inside of this container, let's initiate our project

```bash
npm init -y
```

this will generate a new file `package.json`.

### Installing dependencies

We will rely on [express](https://www.npmjs.com/package/express) to create a simple web service.

```bash
npm install express
```

### Creating index.js file

Now let's create our simple service, by creating a 'index.js' file like this:

```javascript
// Import the express module
import express from "express";

// Create an instance of express
const app = express();

// Define a route handler for the default home page
app.get("/", (req, res) => {
    // Send a response to the client
    res.send("Hello World!");
});

// Start the server and listen on port 3000
app.listen(3000, () => {
    // Log a message to the console once the server is running
    console.log("Server is running on port 3000");
});
```

There is a [index.js](index.js) file with same content if you prefer.

### Executing

Run this command inside of our docker to start the service and expose port 3000.

```bash
node index.js
```

It will show something like this:

```bash
(node:281) [MODULE_TYPELESS_PACKAGE_JSON] Warning: Module type of file:///usr/src/index.js is not specified and it doesn't parse as CommonJS.
Reparsing as ES module because module syntax was detected. This incurs a performance overhead.
To eliminate this warning, add "type": "module" to /usr/src/package.json.
(Use `node --trace-warnings ...` to show where the warning was created)
Server is running on port 3000
```

To cancel it, use `<CTRL>+<c>`

To fix this warning message you can just add this line inside of our package.json file. Be sure that it is inside of "{}". Another option is to initiate using `npm init es6 -y` but then you will need to fill other information inside of package.json file.

```json
"type": "module",
```

Then execute again.

Finally you can access using your browser

* [hello](http://127.0.0.1:3000/)

## Examples

Other examples:

* [LaunchDarkly](https://launchdarkly.com/) [boolean flag](./examples/launchdarkly/)