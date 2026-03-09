# Go Agent Skills

A comprehensive collection of skills for AI coding agents working with **Go (Golang)**. Skills are packaged instructions and scripts that extend agent capabilities for Go development.

Skills follow the [Agent Skills](https://agentskills.io/) format.

## Available Skills

### go-best-practices

Go performance optimization and idiomatic coding guidelines. Contains **50+ rules** across 9 categories, prioritized by impact. Covers everything from memory allocation to interface design.

**Use when:**

- Writing new Go packages, services, or CLI tools
- Reviewing code for performance and idiomatic issues
- Optimizing memory allocation, GC pressure, or concurrency
- Refactoring legacy Go code to modern standards

**Categories covered:**

- Memory & Allocation (Critical)
- Error Handling (Critical)
- Concurrency & Goroutines (Critical)
- Interface Design (High)
- Package Design (High)
- Standard Library Usage (Medium-High)
- Struct & Type Design (Medium)
- Build & Compilation (Medium)
- Code Style & Idioms (Low-Medium)

---

### api-design-guidelines

Review Go HTTP API code for compliance with REST best practices, security, and performance. Audits your code for **80+ rules** covering middleware, routing, validation, and observability.

**Use when:**

- "Review my API"
- "Check API security"
- "Audit my HTTP handlers"
- "Review middleware chain"
- "Check my Go web service against best practices"

**Categories covered:**

- Routing & Middleware (proper use of `http.ServeMux`, chi, gorilla/mux)
- Request Validation (input sanitization, struct tags, custom validators)
- Response Formatting (JSON encoding, error responses, pagination)
- Authentication & Authorization (JWT, OAuth2, RBAC patterns)
- Rate Limiting & Throttling (token bucket, sliding window)
- CORS & Security Headers (CSP, HSTS, X-Frame-Options)
- Logging & Observability (structured logging with slog, OpenTelemetry)
- Graceful Shutdown (signal handling, connection draining)
- API Versioning (URL path, header-based, content negotiation)

---

### go-concurrency-patterns

Go concurrency patterns that scale. Covers goroutine lifecycle management, channel patterns, sync primitives, and context propagation.

**Use when:**

- Designing concurrent or parallel systems
- Building worker pools or fan-out/fan-in pipelines
- Debugging goroutine leaks or race conditions
- Implementing graceful shutdown in concurrent code
- Reviewing concurrent code for correctness

**Patterns covered:**

- Generator pattern
- Fan-out / Fan-in
- Pipeline pattern
- Worker pool with bounded concurrency
- Semaphore pattern
- Or-done channel
- Tee channel
- Bridge channel
- Context-based cancellation trees
- errgroup patterns
- Rate-limited concurrency

---

### go-testing-guidelines

Go testing best practices optimized for AI agents. Contains **30+ rules** across 6 sections covering unit tests, integration tests, benchmarks, and fuzzing.

**Use when:**

- Writing unit tests or table-driven tests
- Setting up integration tests with databases or external services
- Writing benchmarks to measure performance
- Implementing fuzz tests for input validation
- Reviewing test code for coverage and correctness

**Categories covered:**

- Table-Driven Tests (Critical) — subtests, naming, parallel execution
- Mocking & Interfaces (High) — test doubles, interface segregation
- Integration Testing (High) — testcontainers, database fixtures, cleanup
- Benchmarking (Medium) — `testing.B`, profiling, comparison benchmarks
- Fuzz Testing (Medium) — `testing.F`, corpus management, edge cases
- Test Helpers (Medium) — `testing.TB`, cleanup functions, golden files

---

### go-project-structure

Go project layout and architecture patterns. Helps organize code into clean, maintainable packages following community conventions and domain-driven design.

**Use when:**

- Starting a new Go project or microservice
- Refactoring a monolithic codebase into packages
- Designing domain-driven architecture in Go
- Setting up a monorepo with multiple Go modules
- Reviewing project layout for maintainability

**Patterns covered:**

- Standard project layout (cmd/, internal/, pkg/)
- Domain-driven design in Go
- Clean architecture / hexagonal architecture
- Repository pattern
- Wire/dependency injection
- Configuration management (env, YAML, TOML)
- Makefile & task automation

---

### docker-deploy

Build and deploy Go applications with Docker. Optimized multi-stage builds, distroless images, and deployment automation.

**Use when:**

- "Dockerize my Go app"
- "Create a production Dockerfile"
- "Deploy my Go service"
- "Optimize my Docker image size"
- "Set up CI/CD for my Go project"

**Features:**

- Auto-detects project type (web server, CLI, gRPC, worker)
- Generates optimized multi-stage Dockerfiles
- Supports distroless and scratch base images
- Includes docker-compose for local development
- Health check and graceful shutdown patterns
- Returns image size and build metrics

---

### grpc-service-guidelines

gRPC service design and implementation best practices for Go. Covers protobuf design, interceptors, streaming, and error handling.

**Use when:**

- Designing protobuf schemas and service definitions
- Implementing gRPC servers or clients in Go
- Adding interceptors for logging, auth, and tracing
- Working with streaming RPCs
- Reviewing gRPC service code

**Categories covered:**

- Protobuf Design (Critical) — field numbering, backward compatibility, well-known types
- Server Implementation (High) — registration, reflection, health checks
- Interceptors & Middleware (High) — unary/stream interceptors, chaining
- Error Handling (High) — status codes, error details, rich errors
- Streaming Patterns (Medium) — server/client/bidi streaming, flow control
- Client Patterns (Medium) — connection pooling, retries, load balancing
- Testing (Medium) — bufconn, mock servers, integration tests

---

### database-patterns

Go database access patterns and best practices. Covers `database/sql`, SQLX, GORM, migrations, and connection management.

**Use when:**

- Setting up database connections in Go
- Implementing repository patterns with SQL
- Writing database migrations
- Optimizing query performance and connection pooling
- Choosing between `database/sql`, SQLX, and GORM

**Categories covered:**

- Connection Management (Critical) — pool sizing, timeouts, health checks
- Query Patterns (High) — prepared statements, batch operations, CTEs
- Transaction Management (High) — isolation levels, retry logic, savepoints
- Migration Strategies (Medium) — golang-migrate, goose, atlas
- ORM Usage (Medium) — GORM best practices, eager/lazy loading
- Testing (Medium) — sqlmock, testcontainers-go, fixtures

---

## Installation

```bash
# Install using the skills CLI
npx skills add go-agent-skills/go-agent-skills

# Or install specific skills
npx skills add go-agent-skills/go-agent-skills --skill go-best-practices
npx skills add go-agent-skills/go-agent-skills --skill api-design-guidelines

# Install to specific agents
npx skills add go-agent-skills/go-agent-skills -a claude-code -a cursor
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/go-agent-skills/go-agent-skills.git

# Copy skills to your project
cp -r go-agent-skills/skills/go-best-practices .skills/

# Or symlink for automatic updates
ln -s $(pwd)/go-agent-skills/skills/go-best-practices .skills/go-best-practices
```

## Usage

Skills are automatically available once installed. The agent will use them when relevant tasks are detected.

**Examples:**

```
Review this Go handler for performance issues
```

```
Help me design a worker pool with error handling
```

```
Set up table-driven tests for my calculator package
```

```
Dockerize my Go API server for production
```

```
Design a gRPC service for user management
```

## Skill Structure

Each skill contains:

- `SKILL.md` — Instructions for the agent (required)
- `scripts/` — Helper scripts for automation (optional)
- `references/` — Supporting documentation (optional)
- `assets/` — Templates and example files (optional)

### SKILL.md Format

```yaml
---
name: skill-name
description: >
  One sentence describing when to use this skill.
  Include trigger phrases.
---

# Skill Title

Brief description of what the skill does.

## How It Works
...

## Rules
...
```

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a new skill directory under `skills/`
3. Add a `SKILL.md` with proper YAML frontmatter
4. Add scripts and references as needed
5. Submit a pull request

### Skill Quality Checklist

- [ ] `SKILL.md` has valid YAML frontmatter with `name` and `description`
- [ ] Description includes trigger phrases
- [ ] Rules are prioritized by impact
- [ ] Scripts use `#!/bin/bash` and `set -e`
- [ ] SKILL.md is under 500 lines
- [ ] References are in separate files for progressive disclosure

## Compatibility

These skills are compatible with any agent that supports the Agent Skills format:

| Agent | Status |
|-------|--------|
| Claude Code | ✅ Fully supported |
| Cursor | ✅ Fully supported |
| GitHub Copilot | ✅ Fully supported |
| OpenCode | ✅ Fully supported |
| Codex | ✅ Fully supported |
| Windsurf | ✅ Fully supported |
| Goose | ✅ Fully supported |

## ☕ Support this project

If you like this project, you can buy me a coffee.

<a href="https://buymeacoffee.com/dobadat111c" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" height="50">
</a>