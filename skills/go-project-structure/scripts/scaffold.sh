#!/bin/bash
set -e

# Go Project Scaffolding Script
# Generates a new Go project with recommended structure
# Usage: bash scaffold.sh <project-name> --type=<api|cli|lib> [--module=<module-path>]

PROJECT_NAME="${1:?Usage: scaffold.sh <project-name> --type=<api|cli|lib>}"
PROJECT_TYPE="api"
MODULE_PATH=""

for arg in "$@"; do
    case $arg in
        --type=*) PROJECT_TYPE="${arg#*=}" ;;
        --module=*) MODULE_PATH="${arg#*=}" ;;
    esac
done

if [ -z "$MODULE_PATH" ]; then
    MODULE_PATH="github.com/yourorg/$PROJECT_NAME"
fi

echo "Scaffolding Go project: $PROJECT_NAME" >&2
echo "Type: $PROJECT_TYPE" >&2
echo "Module: $MODULE_PATH" >&2

if [ -d "$PROJECT_NAME" ]; then
    echo "ERROR: Directory $PROJECT_NAME already exists" >&2
    exit 1
fi

scaffold_api() {
    mkdir -p "$PROJECT_NAME"/{cmd/"$PROJECT_NAME",internal/{config,domain,handler,service,repository/postgres,platform/{database,logger,server}},migrations,api,deployments,scripts}

    # main.go
    cat > "$PROJECT_NAME/cmd/$PROJECT_NAME/main.go" << 'GOEOF'
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

var version = "dev"

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(),
		syscall.SIGTERM, syscall.SIGINT,
	)
	defer cancel()

	if err := run(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run(ctx context.Context) error {
	// TODO: Load config, wire dependencies, start server
	fmt.Printf("Starting %s %s\n", os.Args[0], version)
	<-ctx.Done()
	fmt.Println("Shutting down...")
	return nil
}
GOEOF

    # config.go
    cat > "$PROJECT_NAME/internal/config/config.go" << 'GOEOF'
package config

import (
	"fmt"
	"os"
)

type Config struct {
	Port        string
	DatabaseURL string
	LogLevel    string
}

func Load() (*Config, error) {
	cfg := &Config{
		Port:        getEnv("PORT", "8080"),
		DatabaseURL: getEnv("DATABASE_URL", ""),
		LogLevel:    getEnv("LOG_LEVEL", "info"),
	}

	if cfg.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	return cfg, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
GOEOF

    # Dockerfile
    cat > "$PROJECT_NAME/deployments/Dockerfile" << DEOF
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /bin/app ./cmd/$PROJECT_NAME

FROM gcr.io/distroless/static-debian12
COPY --from=builder /bin/app /bin/app
EXPOSE 8080
ENTRYPOINT ["/bin/app"]
DEOF

    # Makefile
    cat > "$PROJECT_NAME/Makefile" << 'MEOF'
.PHONY: build test lint run

APP_NAME := $(notdir $(CURDIR))
VERSION  := $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)

build:
	go build -ldflags "-X main.version=$(VERSION)" -o bin/$(APP_NAME) ./cmd/$(APP_NAME)

test:
	go test -race -count=1 ./...

lint:
	golangci-lint run ./...

run:
	go run ./cmd/$(APP_NAME)
MEOF

    # .gitignore
    cat > "$PROJECT_NAME/.gitignore" << 'GEOF'
bin/
*.exe
.env
*.test
coverage.out
vendor/
GEOF
}

scaffold_cli() {
    mkdir -p "$PROJECT_NAME"/{cmd/"$PROJECT_NAME",internal/{cli,config,engine},pkg,testdata}

    cat > "$PROJECT_NAME/cmd/$PROJECT_NAME/main.go" << 'GOEOF'
package main

import (
	"fmt"
	"os"
)

var version = "dev"

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	// TODO: Parse args, execute commands
	fmt.Printf("Version: %s\n", version)
	return nil
}
GOEOF
}

scaffold_lib() {
    mkdir -p "$PROJECT_NAME"/{internal,testdata}

    cat > "$PROJECT_NAME/${PROJECT_NAME}.go" << GOEOF
// Package $PROJECT_NAME provides ...
package ${PROJECT_NAME//-/_}
GOEOF

    cat > "$PROJECT_NAME/${PROJECT_NAME}_test.go" << GOEOF
package ${PROJECT_NAME//-/_}_test
GOEOF

    cat > "$PROJECT_NAME/doc.go" << GOEOF
// Package ${PROJECT_NAME//-/_} provides ...
//
// # Getting Started
//
// ...
package ${PROJECT_NAME//-/_}
GOEOF
}

case "$PROJECT_TYPE" in
    api) scaffold_api ;;
    cli) scaffold_cli ;;
    lib) scaffold_lib ;;
    *) echo "Unknown type: $PROJECT_TYPE (use api, cli, or lib)" >&2; exit 1 ;;
esac

# Initialize go module
cd "$PROJECT_NAME"
go mod init "$MODULE_PATH" 2>/dev/null || true

# README
cat > README.md << REOF
# $PROJECT_NAME

## Development

\`\`\`bash
# Run
make run

# Test
make test

# Build
make build
\`\`\`
REOF

echo "" >&2
echo "Project scaffolded: $PROJECT_NAME ($PROJECT_TYPE)" >&2

# Output JSON
cat << EOF
{
  "project": "$PROJECT_NAME",
  "type": "$PROJECT_TYPE",
  "module": "$MODULE_PATH",
  "path": "$(pwd)"
}
EOF
