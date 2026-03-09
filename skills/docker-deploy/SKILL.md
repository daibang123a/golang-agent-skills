---
name: docker-deploy
description: >
  Build and deploy Go applications with Docker. Generates optimized multi-stage
  Dockerfiles, distroless images, docker-compose configs, and CI/CD pipelines.
  Use when dockerizing a Go app, optimizing image size, or setting up deployment.
  Triggers: "Dockerize my Go app", "Create a Dockerfile", "Deploy my Go service",
  "Optimize Docker image", "CI/CD pipeline", "Production Dockerfile".
---

# Docker Deploy for Go

Build and deploy Go applications with production-optimized Docker images. Auto-detects project type and generates appropriate configurations.

## How It Works

1. Agent detects the project type by examining `go.mod`, `main.go`, and import paths
2. Agent generates an optimized multi-stage Dockerfile
3. Agent creates supporting files (docker-compose, .dockerignore, CI config)
4. Agent reports image size and build metrics

## Project Detection

| Signal | Project Type | Base Image |
|--------|-------------|------------|
| `net/http`, `chi`, `gin`, `echo` | Web server | `distroless/static` |
| `google.golang.org/grpc` | gRPC service | `distroless/static` |
| `cobra`, `urfave/cli` | CLI tool | `distroless/static` |
| No network imports | Worker/batch | `scratch` |

## Dockerfile Templates

### Web Service (Default)

```dockerfile
# ---- Build Stage ----
FROM golang:1.22-alpine AS builder

# Install certificates and timezone data
RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -X main.version=$(git describe --tags --always 2>/dev/null || echo dev)" \
    -trimpath \
    -o /bin/app \
    ./cmd/myservice

# ---- Runtime Stage ----
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /bin/app /bin/app

EXPOSE 8080

USER nonroot:nonroot

ENTRYPOINT ["/bin/app"]
```

### Scratch Image (Minimal)

```dockerfile
FROM golang:1.22-alpine AS builder
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o /bin/app ./cmd/myservice

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /bin/app /bin/app
EXPOSE 8080
ENTRYPOINT ["/bin/app"]
```

### With Private Modules

```dockerfile
FROM golang:1.22-alpine AS builder
ARG GITHUB_TOKEN
RUN apk add --no-cache git ca-certificates
RUN git config --global url."https://${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
ENV GOPRIVATE=github.com/yourorg/*
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o /bin/app ./cmd/myservice

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /bin/app /bin/app
ENTRYPOINT ["/bin/app"]
```

## Docker Compose (Development)

```yaml
services:
  app:
    build:
      context: .
      dockerfile: deployments/Dockerfile
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://user:pass@db:5432/mydb?sslmode=disable
      - LOG_LEVEL=debug
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: mydb
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  pgdata:
```

## .dockerignore

```
.git
.github
.env
*.md
!README.md
bin/
vendor/
testdata/
*_test.go
docker-compose*.yml
Makefile
.golangci.yml
```

## Optimization Rules

| # | Rule | Description |
|---|------|-------------|
| D1 | **Use multi-stage builds** | Builder stage with full toolchain, runtime stage with minimal image. |
| D2 | **Cache go mod download** | Copy `go.mod` and `go.sum` before source code to leverage Docker layer cache. |
| D3 | **Use CGO_ENABLED=0** | Static binary, no C dependencies, compatible with scratch/distroless. |
| D4 | **Use -ldflags="-s -w"** | Strip debug info and symbol table. Reduces binary size by ~30%. |
| D5 | **Use -trimpath** | Removes local file paths from binary. Improves reproducibility and security. |
| D6 | **Run as nonroot** | Use `USER nonroot:nonroot` with distroless or create a non-root user. |
| D7 | **Set EXPOSE** | Document the port the application listens on. |
| D8 | **Add health check** | `HEALTHCHECK CMD ["/bin/app", "--health"]` or use an HTTP endpoint. |
| D9 | **Use .dockerignore** | Exclude tests, docs, CI configs, and .git from the build context. |
| D10 | **Pin base image versions** | `golang:1.22-alpine`, not `golang:latest`. Pin distroless version for reproducibility. |

## CI/CD (GitHub Actions)

```yaml
name: Build & Deploy

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Test
        run: go test -race -count=1 ./...

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: deployments/Dockerfile
          push: ${{ github.event_name == 'push' && startsWith(github.ref, 'refs/tags/') }}
          tags: |
            ghcr.io/${{ github.repository }}:latest
            ghcr.io/${{ github.repository }}:${{ github.sha }}
```

## Generate Script

```bash
bash skills/docker-deploy/scripts/generate-dockerfile.sh /path/to/project
```
