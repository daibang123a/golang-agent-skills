---
name: go-best-practices
description: >
  Go performance optimization and idiomatic coding guidelines with 50+ rules
  across 9 categories. Use when writing new Go code, reviewing for performance
  issues, optimizing memory or concurrency, or refactoring to idiomatic Go.
  Triggers: "Review my Go code", "Optimize Go performance", "Make this idiomatic",
  "Check for Go best practices".
---

# Go Best Practices

Performance optimization and idiomatic Go coding guidelines. 50+ rules across 9 categories, prioritized by impact.

## How It Works

1. Agent receives Go code to write or review
2. Agent loads this skill and applies relevant rules by category
3. Rules are applied in priority order: Critical → High → Medium → Low
4. Agent provides specific, actionable feedback with code examples

## Rules

### 1. Memory & Allocation (Critical)

| # | Rule | Description |
|---|------|-------------|
| M1 | **Pre-allocate slices** | Use `make([]T, 0, n)` when size is known or estimable. Reduces GC pressure from repeated growth. |
| M2 | **Avoid unnecessary pointers** | Value types on the stack are cheaper than heap-allocated pointers. Only use pointers when mutation or nil semantics are needed. |
| M3 | **Use sync.Pool for hot-path allocations** | Pool frequently allocated objects (buffers, structs) in performance-critical paths. Always reset before returning to pool. |
| M4 | **Prefer strings.Builder for concatenation** | Never use `+` in loops. `strings.Builder` avoids intermediate allocations. |
| M5 | **Avoid []byte ↔ string conversions** | Each conversion allocates. Use `strings.Builder` or work consistently with one type. |
| M6 | **Use appropriate map sizing** | `make(map[K]V, n)` with expected capacity avoids rehashing. Maps never shrink — consider periodic recreation for long-lived maps. |
| M7 | **Watch for slice memory leaks** | Slicing a large slice keeps the full backing array alive. Copy to a new slice if retaining a small portion. |
| M8 | **Prefer value receivers for small structs** | Structs ≤ 3 words are cheaper to copy than to indirect through a pointer. |

### 2. Error Handling (Critical)

| # | Rule | Description |
|---|------|-------------|
| E1 | **Always handle errors** | Never use `_` to discard errors unless explicitly justified with a comment. |
| E2 | **Wrap errors with context** | Use `fmt.Errorf("operation failed: %w", err)` to add context while preserving the error chain. |
| E3 | **Define sentinel errors as package-level vars** | `var ErrNotFound = errors.New("not found")`. Callers use `errors.Is()`. |
| E4 | **Define error types for structured info** | Use custom types implementing `error` when callers need to extract fields. Callers use `errors.As()`. |
| E5 | **Don't panic in library code** | Libraries should return errors. Panics are only acceptable for truly unrecoverable programmer errors. |
| E6 | **Use errors.Is/As, not == or type assertions** | Direct comparison breaks when errors are wrapped. Always use the `errors` package functions. |
| E7 | **Don't log and return** | Either log the error and handle it, or wrap and return it. Never both — it creates duplicate log entries. |

### 3. Concurrency & Goroutines (Critical)

| # | Rule | Description |
|---|------|-------------|
| C1 | **Always ensure goroutine termination** | Every goroutine must have a clear exit path. Use `context.Context` for cancellation. |
| C2 | **Avoid goroutine leaks** | Use `errgroup`, `context.WithCancel`, or explicit done channels. Verify with `goleak` in tests. |
| C3 | **Protect shared state** | Use `sync.Mutex`, `sync.RWMutex`, or channels. Never share memory without synchronization. |
| C4 | **Prefer channels for communication, mutexes for state** | Channels are for passing data/signals between goroutines. Mutexes are for protecting shared data structures. |
| C5 | **Use context for cancellation propagation** | Pass `context.Context` as the first parameter. Honor cancellation in long-running operations. |
| C6 | **Never start goroutines in init()** | Init functions run before main. Goroutine scheduling is unpredictable during init. |
| C7 | **Use sync.Once for one-time initialization** | Thread-safe lazy initialization. Never hand-roll double-checked locking. |

### 4. Interface Design (High)

| # | Rule | Description |
|---|------|-------------|
| I1 | **Keep interfaces small** | 1-3 methods ideal. "The bigger the interface, the weaker the abstraction." |
| I2 | **Define interfaces at the consumer** | The package that *uses* the interface should define it, not the package that implements it. |
| I3 | **Accept interfaces, return structs** | Functions should accept the narrowest interface needed and return concrete types. |
| I4 | **Use standard interfaces** | Implement `io.Reader`, `io.Writer`, `fmt.Stringer`, `sort.Interface`, `encoding.TextMarshaler` when applicable. |
| I5 | **Don't export interfaces for testing only** | If an interface exists only for mocking, define it in the test file with `_test.go` suffix. |
| I6 | **Avoid interface pollution** | Don't create interfaces until you have 2+ implementations or a clear testing need. |

### 5. Package Design (High)

| # | Rule | Description |
|---|------|-------------|
| P1 | **Name packages after what they provide** | `http`, `json`, `auth` — not `utils`, `helpers`, `common`, `misc`. |
| P2 | **Avoid package-level state** | Global variables make testing hard and introduce race conditions. Use dependency injection. |
| P3 | **Keep internal/ for private packages** | Use `internal/` to prevent external imports of implementation details. |
| P4 | **One package, one purpose** | A package should have a single, well-defined responsibility. |
| P5 | **Minimize exported API** | Export only what consumers need. Unexported symbols can always be promoted later. |
| P6 | **Avoid circular dependencies** | Circular imports don't compile. Design package boundaries to flow in one direction. |
| P7 | **Use doc.go for package-level docs** | Put package documentation in a separate `doc.go` file for large packages. |

### 6. Standard Library Usage (Medium-High)

| # | Rule | Description |
|---|------|-------------|
| S1 | **Use `context.Context` consistently** | First parameter of functions that do I/O, cross boundaries, or might need cancellation. |
| S2 | **Use `slog` for structured logging** | Go 1.21+ includes `log/slog`. Prefer it over third-party loggers for new projects. |
| S3 | **Use `net/http` ServeMux for simple routing** | Go 1.22+ `http.ServeMux` supports method-based routing and path parameters. |
| S4 | **Use `encoding/json` with struct tags** | Always define JSON field names explicitly: `json:"field_name"`. Use `omitempty` intentionally. |
| S5 | **Use `time.Duration` not integers** | Never `sleep(5)`. Always `time.Sleep(5 * time.Second)`. APIs should accept `time.Duration`. |
| S6 | **Use `io.ReadAll` with caution** | Reading entire streams into memory can OOM. Use streaming where possible. |
| S7 | **Close resources with defer** | `defer file.Close()`, `defer rows.Close()`, `defer resp.Body.Close()`. Close immediately after open. |

### 7. Struct & Type Design (Medium)

| # | Rule | Description |
|---|------|-------------|
| T1 | **Order struct fields by alignment** | Group fields by size (8-byte, 4-byte, etc.) to minimize padding. Use `fieldalignment` tool. |
| T2 | **Use functional options for complex constructors** | `WithTimeout(d)`, `WithLogger(l)` pattern for optional configuration. |
| T3 | **Make zero values useful** | Design structs so the zero value is a valid, working default. `sync.Mutex{}` and `bytes.Buffer{}` are good examples. |
| T4 | **Use type aliases for domain clarity** | `type UserID int64`, `type Email string`. Adds type safety and documentation. |
| T5 | **Avoid deeply nested structs** | Flatten where possible. Embedding is fine for composition, not for deep hierarchies. |
| T6 | **Use enums via const + iota** | Define typed constants with `iota`. Add a `String()` method and validation. |

### 8. Build & Compilation (Medium)

| # | Rule | Description |
|---|------|-------------|
| B1 | **Use build tags for platform code** | `//go:build linux` for platform-specific files. |
| B2 | **Set ldflags for version info** | `-ldflags "-X main.version=v1.2.3"` at build time. |
| B3 | **Use `go generate` for code generation** | Document `//go:generate` directives clearly. Check in generated code. |
| B4 | **Minimize CGO usage** | CGO breaks cross-compilation and adds complexity. Use pure Go alternatives when available. |
| B5 | **Use `go mod tidy` regularly** | Keep `go.mod` and `go.sum` clean. Remove unused dependencies. |
| B6 | **Enable race detector in CI** | Always run `go test -race ./...` in CI pipelines. |

### 9. Code Style & Idioms (Low-Medium)

| # | Rule | Description |
|---|------|-------------|
| Y1 | **Use gofmt/goimports** | Non-negotiable. Run on save. |
| Y2 | **Name receivers consistently** | Use short, 1-2 letter names derived from the type: `func (s *Server)`, `func (c *Client)`. |
| Y3 | **Avoid named return values** | Except when they improve documentation for functions with multiple returns of the same type. |
| Y4 | **Use early returns (guard clauses)** | Reduce nesting by handling error cases first and returning early. |
| Y5 | **Keep functions short** | Functions over 50 lines are usually doing too much. Extract helper functions. |
| Y6 | **Comment exported symbols** | All exported types, functions, and constants must have doc comments starting with the name. |
| Y7 | **Use meaningful variable names** | Short names (`i`, `n`, `err`) for small scopes. Descriptive names for larger scopes. |

## Quick Reference

Run the analysis script to check a Go project against these rules:

```bash
bash skills/go-best-practices/scripts/lint-check.sh /path/to/project
```

For detailed allocation analysis, see `references/allocation-guide.md`.
For interface design patterns, see `references/interface-patterns.md`.
