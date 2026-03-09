---
name: go-project-structure
description: >
  Go project layout and architecture patterns. Organize code into clean,
  maintainable packages following community conventions. Use when starting
  a new Go project, refactoring a codebase, designing domain-driven
  architecture, or reviewing project layout. Triggers: "Project structure",
  "Organize my Go project", "Clean architecture Go", "New Go service",
  "Refactor packages", "Monorepo setup".
---

# Go Project Structure

Project layout and architecture patterns for Go applications. Covers service structure, CLI tools, libraries, and monorepos.

## How It Works

1. Agent identifies the project type (service, CLI, library, monorepo)
2. Agent applies the appropriate layout template
3. Agent generates directory structure with standard files
4. Agent organizes existing code into the recommended structure

## Layouts

### 1. Web Service / API (Most Common)

```
myservice/
├── cmd/
│   └── myservice/
│       └── main.go              # Entry point, wiring, startup
├── internal/
│   ├── config/
│   │   └── config.go            # Configuration loading
│   ├── domain/
│   │   ├── user.go              # Domain types & interfaces
│   │   └── order.go
│   ├── handler/
│   │   ├── user.go              # HTTP handlers
│   │   ├── order.go
│   │   └── middleware.go
│   ├── repository/
│   │   ├── postgres/
│   │   │   ├── user.go          # PostgreSQL implementation
│   │   │   └── migrations/
│   │   └── redis/
│   │       └── cache.go
│   ├── service/
│   │   ├── user.go              # Business logic
│   │   └── order.go
│   └── platform/
│       ├── database/
│       │   └── postgres.go      # Database connection setup
│       ├── logger/
│       │   └── logger.go
│       └── server/
│           └── server.go        # HTTP server setup
├── migrations/
│   ├── 001_create_users.up.sql
│   └── 001_create_users.down.sql
├── api/
│   └── openapi.yaml             # API specification
├── deployments/
│   ├── Dockerfile
│   └── docker-compose.yml
├── scripts/
│   ├── migrate.sh
│   └── seed.sh
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

### 2. CLI Tool

```
mytool/
├── cmd/
│   └── mytool/
│       └── main.go
├── internal/
│   ├── cli/
│   │   ├── root.go              # Root command (cobra/urfave)
│   │   ├── init.go              # Subcommands
│   │   └── run.go
│   ├── config/
│   │   └── config.go
│   └── engine/
│       └── processor.go         # Core logic
├── pkg/                         # Public API (if any)
│   └── formatter/
│       └── formatter.go
├── testdata/
│   └── fixtures/
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

### 3. Library / Package

```
mylib/
├── mylib.go                     # Primary package file
├── mylib_test.go
├── option.go                    # Functional options
├── errors.go                    # Exported error types
├── internal/
│   └── parser/                  # Internal helpers
│       └── parser.go
├── examples_test.go             # Testable examples (ExampleXxx)
├── doc.go                       # Package documentation
├── testdata/
│   └── fixtures/
├── go.mod
├── go.sum
└── README.md
```

### 4. Monorepo

```
platform/
├── go.work                      # Go workspace file
├── go.work.sum
├── services/
│   ├── users/
│   │   ├── cmd/users/main.go
│   │   ├── internal/
│   │   ├── go.mod
│   │   └── go.sum
│   ├── orders/
│   │   ├── cmd/orders/main.go
│   │   ├── internal/
│   │   ├── go.mod
│   │   └── go.sum
│   └── gateway/
│       ├── cmd/gateway/main.go
│       ├── internal/
│       ├── go.mod
│       └── go.sum
├── libs/
│   ├── auth/                    # Shared auth library
│   │   ├── auth.go
│   │   ├── go.mod
│   │   └── go.sum
│   └── observability/
│       ├── tracing.go
│       ├── go.mod
│       └── go.sum
├── proto/                       # Shared protobuf definitions
│   ├── user/v1/user.proto
│   └── order/v1/order.proto
├── deployments/
│   ├── docker-compose.yml
│   └── k8s/
├── Makefile
└── README.md
```

## Architecture Rules

| # | Rule | Description |
|---|------|-------------|
| A1 | **cmd/ for entry points only** | `main.go` should only parse config, wire dependencies, and call `run()`. No business logic. |
| A2 | **internal/ for private packages** | Everything under `internal/` cannot be imported by external modules. Use it aggressively. |
| A3 | **pkg/ is optional and rare** | Only use `pkg/` for code explicitly designed as a reusable library. Most projects don't need it. |
| A4 | **Domain types are dependency-free** | Domain structs and interfaces in `internal/domain/` should not import infrastructure packages. |
| A5 | **Dependencies flow inward** | handler → service → repository → database. Never the reverse. |
| A6 | **One main.go per binary** | Each binary gets its own directory under `cmd/`. |
| A7 | **Interfaces live with consumers** | The `service` package defines the `Repository` interface, not the `repository` package. |
| A8 | **Configuration via environment** | Use environment variables in production. Support `.env` files for development. |

## Key Files

### main.go Pattern

```go
package main

import (
    "context"
    "fmt"
    "os"
    "os/signal"
    "syscall"
)

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
    // Load config
    cfg, err := config.Load()
    if err != nil {
        return fmt.Errorf("loading config: %w", err)
    }

    // Initialize dependencies
    db, err := database.Connect(ctx, cfg.DatabaseURL)
    if err != nil {
        return fmt.Errorf("connecting to database: %w", err)
    }
    defer db.Close()

    // Wire services
    userRepo := postgres.NewUserRepository(db)
    userSvc := service.NewUserService(userRepo)
    handler := handler.New(userSvc)

    // Start server
    return server.Run(ctx, cfg.Port, handler)
}
```

### Makefile Pattern

```makefile
.PHONY: build test lint run migrate

APP_NAME := myservice
VERSION  := $(shell git describe --tags --always --dirty)

build:
	go build -ldflags "-X main.version=$(VERSION)" -o bin/$(APP_NAME) ./cmd/$(APP_NAME)

test:
	go test -race -count=1 ./...

test-integration:
	go test -race -tags=integration -count=1 ./...

lint:
	golangci-lint run ./...

run:
	go run ./cmd/$(APP_NAME)

migrate-up:
	migrate -path migrations -database "$(DATABASE_URL)" up

migrate-down:
	migrate -path migrations -database "$(DATABASE_URL)" down 1

generate:
	go generate ./...

docker:
	docker build -t $(APP_NAME):$(VERSION) .
```

## Scaffolding Script

Generate a new project structure:

```bash
bash skills/go-project-structure/scripts/scaffold.sh myservice --type=api
```

For domain-driven design patterns, see `references/ddd-patterns.md`.
For dependency injection patterns, see `references/di-patterns.md`.
