# Stage 1: Build the Go application
# Use the official Golang image based on Alpine Linux as the base image
FROM golang:alpine AS base

# Set the working directory inside the container
WORKDIR /go/src/app

# Copy the Go source file into the container
COPY main.go ./

# Initialize the Go module
RUN go mod init hello-app

# Build the Go application for Linux with CGO disabled
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o ./hello-app .

# Stage 2: Create the final image
# Use the distroless static image based on Debian 12 as the base image
FROM gcr.io/distroless/static-debian12

# Copy the built Go application from the previous stage
# Set the ownership to nonroot user
COPY --from=base --chown=nonroot:nonroot /go/src/app/hello-app /

# Switch to a non-root user for better security
USER nonroot

# Set the entry point to the Go application
ENTRYPOINT ["/hello-app"]