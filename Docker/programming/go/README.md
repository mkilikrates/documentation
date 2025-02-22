# Using go on docker

This way, you don't need to install anything local as well as you can easialy change between different version as you need.

## Getting Start with Hello World

As I explained [earlier](../../programming/), we can use a docker to start a new code, in our case, let's assume we will export a web service to your local host on port `8080`, so we will use this:

```bash
mkdir my_app
cd my_app
docker run -it --rm -v ${PWD}:/usr/src/myapp -w /usr/src/myapp -p 8080:8080  golang /bin/bash
```

*Note*: We are running this docker as root. So you may need to change permissions and ownership later.

### Initilize a new go module

Now, we are inside of this container, let's initiate our project

```bash
go mod init hello/world
```

this will generate a new file `go.mod`.

### Creating main.go file

Now let's create our simple service, by creating a 'main.go' file like this:

```go
package main

import (
    "fmt"
    "log"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    log.Println("INFO: Requested received: ", r.URL.Path, " | method: ", r.Method)
    fmt.Fprintf(w, "Hello, World!.\n")
}

func main() {
    log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
    http.HandleFunc("/", handler)
    fmt.Println("Server starting on http://localhost:8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatalf("Server failed to start: %v", err)
    }
}
```

There is a [main.go](main.go) file with same content if you prefer.

### Executing

Run this command inside of our docker to start the service and expose port 8080.

```bash
go run .
```

It will show something like this:

```bash
Server starting on http://localhost:8080
```

Finally you can access using your browser

* [hello](http://127.0.0.1:8080/)

To cancel it, use `<CTRL>+<c>`

### Compiling

One advantage of go is that we can compile, so it will became a executable file that you don't need to use with go environment.
More information can be found on [official documentation](https://pkg.go.dev/go/build).

To compile you can do like this:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o ./app .
```

It will produce a `app` file. Then you can even exit from our container then just execute

```bash
./app
```

It will show something like this:

```bash
Server starting on http://localhost:8080
```

Finally you can access using your browser

* [hello](http://127.0.0.1:8080/)

*Note*: If you are running this on WSL, you need to access your container ip, so you can use this

```bash
ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
```

then open your browser with the ip address it shows, like `http://172.31.99.41:8080`.

To cancel it, use `<CTRL>+<c>`
