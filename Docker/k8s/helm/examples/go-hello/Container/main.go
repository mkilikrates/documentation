package main

import (
    "fmt"
    "log"
    "net/http"
)

// handler handles HTTP requests to the root URL.
// It logs the request details and responds with "Hello, World!".
func handler(w http.ResponseWriter, r *http.Request) {
    log.Println("INFO: Requested received: ", r.URL.Path, " | method: ", r.Method, " | from: ", r.RemoteAddr)   
    fmt.Fprintf(w, "Hello, World!.\n")
}

func main() {
    // Set log flags to include the date, time, and short file name in log messages.
    log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
    // Register the handler function for the root URL path.
    http.HandleFunc("/", handler)
    // Print a message to the console indicating the server is starting.
    fmt.Println("Server starting on http://localhost:8080")
    // Start the HTTP server on port 8080 and log any errors if the server fails to start.
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatalf("Server failed to start: %v", err)
    }
}
