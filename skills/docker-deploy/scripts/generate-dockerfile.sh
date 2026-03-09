#!/bin/bash
set -e

# Generate Dockerfile for Go Project
# Detects project type and generates an optimized multi-stage Dockerfile
# Usage: bash generate-dockerfile.sh /path/to/project [output-path]

PROJECT_DIR="${1:-.}"
OUTPUT="${2:-$PROJECT_DIR/Dockerfile}"

echo "=== Go Dockerfile Generator ===" >&2
echo "Project: $PROJECT_DIR" >&2

cleanup() {
    rm -f /tmp/dockerfile-gen-$$.tmp
}
trap cleanup EXIT

cd "$PROJECT_DIR"

# Detect Go version from go.mod
GO_VERSION=$(grep "^go " go.mod 2>/dev/null | awk '{print $2}' || echo "1.22")

# Detect main package
MAIN_PKG=""
for dir in cmd/*/; do
    if [ -f "$dir/main.go" ] || [ -f "${dir}main.go" ]; then
        MAIN_PKG="./$dir"
        break
    fi
done
if [ -z "$MAIN_PKG" ] && [ -f "main.go" ]; then
    MAIN_PKG="."
fi

if [ -z "$MAIN_PKG" ]; then
    echo "ERROR: No main package found" >&2
    exit 1
fi

echo "Go version: $GO_VERSION" >&2
echo "Main package: $MAIN_PKG" >&2

# Detect project type
PROJECT_TYPE="worker"
if grep -rq "net/http\|chi\|gin\|echo\|fiber" --include="*.go" . 2>/dev/null; then
    PROJECT_TYPE="web"
elif grep -rq "google.golang.org/grpc" go.mod 2>/dev/null; then
    PROJECT_TYPE="grpc"
elif grep -rq "cobra\|urfave/cli" go.mod 2>/dev/null; then
    PROJECT_TYPE="cli"
fi

echo "Project type: $PROJECT_TYPE" >&2

# Detect port
PORT="8080"
if [ "$PROJECT_TYPE" = "grpc" ]; then
    PORT="50051"
fi

# Detect if CGO is needed
NEEDS_CGO="false"
if grep -rq "\"C\"" --include="*.go" . 2>/dev/null; then
    NEEDS_CGO="true"
fi

# Generate Dockerfile
cat > "$OUTPUT" << DOCKERFILE
# ---- Build Stage ----
FROM golang:${GO_VERSION}-alpine AS builder

RUN apk add --no-cache ca-certificates tzdata git

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \\
    -ldflags="-s -w" \\
    -trimpath \\
    -o /bin/app \\
    ${MAIN_PKG}

# ---- Runtime Stage ----
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /bin/app /bin/app

EXPOSE ${PORT}

USER nonroot:nonroot

ENTRYPOINT ["/bin/app"]
DOCKERFILE

# Generate .dockerignore if not exists
if [ ! -f "$PROJECT_DIR/.dockerignore" ]; then
    cat > "$PROJECT_DIR/.dockerignore" << 'DIGNORE'
.git
.github
.env
*.md
!README.md
bin/
testdata/
*_test.go
docker-compose*.yml
Makefile
.golangci.yml
DIGNORE
    echo "Created .dockerignore" >&2
fi

echo "Dockerfile written to: $OUTPUT" >&2

# Output JSON
cat << EOF
{
  "project": "$PROJECT_DIR",
  "type": "$PROJECT_TYPE",
  "go_version": "$GO_VERSION",
  "main_package": "$MAIN_PKG",
  "port": $PORT,
  "cgo": $NEEDS_CGO,
  "dockerfile": "$OUTPUT"
}
EOF
