---
name: api-design-guidelines
description: >
  Review Go HTTP API code for compliance with REST best practices, security,
  and performance. 80+ rules covering routing, middleware, validation, auth,
  and observability. Use when building or reviewing Go web services, HTTP
  handlers, REST APIs, or middleware chains. Triggers: "Review my API",
  "Check API security", "Audit my handlers", "Review middleware".
---

# Go API Design Guidelines

Review and build Go HTTP APIs following REST best practices, security hardening, and production-grade patterns. 80+ rules across 9 categories.

## How It Works

1. Agent examines HTTP handler code, middleware, routing, and configuration
2. Agent applies rules by category in priority order
3. Agent suggests specific fixes with idiomatic Go code examples
4. Agent references supporting docs for deep-dive topics

## Rules

### 1. Routing & Middleware (Critical)

| # | Rule | Description |
|---|------|-------------|
| R1 | **Use Go 1.22+ ServeMux or a minimal router** | `http.ServeMux` now supports `GET /users/{id}`. Prefer stdlib for simple APIs. Use `chi` or `gorilla/mux` only when pattern matching is insufficient. |
| R2 | **Apply middleware in correct order** | Order matters: Recovery → Logging → CORS → Auth → Rate Limit → Handler. |
| R3 | **Use middleware for cross-cutting concerns** | Authentication, logging, tracing, rate limiting, and CORS belong in middleware, not in handlers. |
| R4 | **Group routes by resource** | `/api/v1/users`, `/api/v1/users/{id}`, `/api/v1/users/{id}/orders`. |
| R5 | **Use http.Handler interface** | All middleware should accept and return `http.Handler` for composability. |
| R6 | **Set timeouts on http.Server** | Always set `ReadTimeout`, `WriteTimeout`, `IdleTimeout`. Never use `http.ListenAndServe` with default server. |

```go
// GOOD: Production server with timeouts
srv := &http.Server{
    Addr:         ":8080",
    Handler:      mux,
    ReadTimeout:  5 * time.Second,
    WriteTimeout: 10 * time.Second,
    IdleTimeout:  120 * time.Second,
}
```

### 2. Request Handling (Critical)

| # | Rule | Description |
|---|------|-------------|
| Q1 | **Validate all input** | Never trust client input. Validate struct fields, query params, path params. |
| Q2 | **Limit request body size** | Use `http.MaxBytesReader` to prevent memory exhaustion from large payloads. |
| Q3 | **Use json.Decoder, not io.ReadAll + json.Unmarshal** | Decoder streams and can enforce `DisallowUnknownFields()`. |
| Q4 | **Return early on validation errors** | Don't process a request if input is invalid. Return 400 immediately. |
| Q5 | **Bind path params safely** | Always validate and convert path parameters. Never use raw strings in queries. |

```go
// GOOD: Safe request parsing
func handleCreateUser(w http.ResponseWriter, r *http.Request) {
    // Limit body size
    r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1MB

    var req CreateUserRequest
    dec := json.NewDecoder(r.Body)
    dec.DisallowUnknownFields()
    if err := dec.Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid request body")
        return
    }

    if err := validate(req); err != nil {
        respondError(w, http.StatusBadRequest, err.Error())
        return
    }
    // ... process
}
```

### 3. Response Formatting (High)

| # | Rule | Description |
|---|------|-------------|
| F1 | **Use consistent error response format** | `{"error": {"code": "NOT_FOUND", "message": "User not found"}}`. |
| F2 | **Set Content-Type header** | Always set `Content-Type: application/json` before writing JSON responses. |
| F3 | **Use proper HTTP status codes** | 200 OK, 201 Created, 204 No Content, 400 Bad Request, 401, 403, 404, 409 Conflict, 422, 429, 500. |
| F4 | **Implement pagination** | Use cursor-based or offset-based pagination for list endpoints. Include `next_cursor` or `total` in response. |
| F5 | **Use envelope for collections** | `{"data": [...], "pagination": {"next_cursor": "abc", "has_more": true}}`. |
| F6 | **Handle Content Negotiation** | Check `Accept` header. Support `application/json` at minimum. |

```go
// GOOD: Consistent response helpers
func respondJSON(w http.ResponseWriter, status int, data any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(data)
}

func respondError(w http.ResponseWriter, status int, message string) {
    respondJSON(w, status, map[string]any{
        "error": map[string]any{
            "code":    http.StatusText(status),
            "message": message,
        },
    })
}
```

### 4. Authentication & Authorization (High)

| # | Rule | Description |
|---|------|-------------|
| A1 | **Use middleware for auth** | Extract token, validate, set user in context. Never repeat auth logic in handlers. |
| A2 | **Store auth info in context** | Use typed keys: `type ctxKey string; const userKey ctxKey = "user"`. |
| A3 | **Validate JWT claims properly** | Check `exp`, `iss`, `aud`. Use a well-tested library (golang-jwt/jwt). |
| A4 | **Implement RBAC in middleware** | Check roles/permissions before handler execution. Return 403 for unauthorized. |
| A5 | **Never log tokens or secrets** | Redact sensitive data in logs. Never include auth headers in error responses. |
| A6 | **Use bcrypt for password hashing** | `golang.org/x/crypto/bcrypt` with cost ≥ 12. Never store plaintext passwords. |

### 5. Rate Limiting & Throttling (High)

| # | Rule | Description |
|---|------|-------------|
| L1 | **Implement rate limiting** | Use `golang.org/x/time/rate` for token bucket. Key by IP or authenticated user. |
| L2 | **Return 429 with Retry-After** | Include `Retry-After` header with seconds until the client can retry. |
| L3 | **Use sliding window for APIs** | Token bucket for burst tolerance, sliding window for strict limits. |
| L4 | **Rate limit by endpoint** | Different limits for read vs. write operations. |

### 6. Security Headers & CORS (High)

| # | Rule | Description |
|---|------|-------------|
| H1 | **Set security headers** | `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Strict-Transport-Security`. |
| H2 | **Configure CORS properly** | Never use `Access-Control-Allow-Origin: *` in production. Whitelist specific origins. |
| H3 | **Prevent CSRF** | Use `SameSite=Strict` cookies and CSRF tokens for state-changing operations. |
| H4 | **Sanitize output** | Escape HTML in responses to prevent XSS if content is rendered. |

### 7. Logging & Observability (Medium-High)

| # | Rule | Description |
|---|------|-------------|
| O1 | **Use structured logging (slog)** | `slog.Info("request", "method", r.Method, "path", r.URL.Path, "duration", d)`. |
| O2 | **Log request ID in every log line** | Generate a request ID in middleware, add to context, include in all logs. |
| O3 | **Instrument with OpenTelemetry** | Use `otel` for traces and metrics. Propagate trace context through services. |
| O4 | **Log at appropriate levels** | Error: failures. Warn: degraded. Info: lifecycle events. Debug: diagnostic detail. |
| O5 | **Implement health check endpoint** | `GET /healthz` returns 200 for liveness. `GET /readyz` checks dependencies. |

### 8. Graceful Shutdown (Medium)

| # | Rule | Description |
|---|------|-------------|
| G1 | **Handle OS signals** | Listen for `SIGTERM` and `SIGINT`. Initiate graceful shutdown. |
| G2 | **Drain connections before exit** | Use `server.Shutdown(ctx)` with a deadline context. |
| G3 | **Close dependencies in order** | HTTP server first, then background workers, then database, then metrics. |

```go
// GOOD: Graceful shutdown pattern
func run(ctx context.Context) error {
    ctx, cancel := signal.NotifyContext(ctx, syscall.SIGTERM, syscall.SIGINT)
    defer cancel()

    srv := &http.Server{Addr: ":8080", Handler: mux}

    go func() {
        <-ctx.Done()
        shutdownCtx, shutdownCancel := context.WithTimeout(
            context.Background(), 10*time.Second,
        )
        defer shutdownCancel()
        srv.Shutdown(shutdownCtx)
    }()

    slog.Info("server starting", "addr", srv.Addr)
    if err := srv.ListenAndServe(); err != http.ErrServerClosed {
        return err
    }
    return nil
}
```

### 9. API Versioning (Medium)

| # | Rule | Description |
|---|------|-------------|
| V1 | **Use URL path versioning** | `/api/v1/users`, `/api/v2/users`. Simplest and most explicit. |
| V2 | **Don't break existing versions** | Add new fields (backward compatible). Never remove or rename fields in the same version. |
| V3 | **Deprecate with headers** | `Sunset: Sat, 01 Jan 2025 00:00:00 GMT` and `Deprecation: true` headers. |

## Quick Reference

Run the API audit script:

```bash
bash skills/api-design-guidelines/scripts/api-audit.sh /path/to/project
```

For authentication patterns, see `references/auth-patterns.md`.
For OpenTelemetry setup, see `references/otel-setup.md`.
