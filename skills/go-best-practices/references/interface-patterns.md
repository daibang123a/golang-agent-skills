# Go Interface Patterns

## The Interface Segregation Principle in Go

```go
// BAD: fat interface — forces implementers to satisfy everything
type Repository interface {
    Create(ctx context.Context, user *User) error
    Get(ctx context.Context, id string) (*User, error)
    Update(ctx context.Context, user *User) error
    Delete(ctx context.Context, id string) error
    List(ctx context.Context, filter Filter) ([]*User, error)
    Count(ctx context.Context, filter Filter) (int, error)
    Export(ctx context.Context, format string) ([]byte, error)
}

// GOOD: small, focused interfaces
type UserReader interface {
    Get(ctx context.Context, id string) (*User, error)
    List(ctx context.Context, filter Filter) ([]*User, error)
}

type UserWriter interface {
    Create(ctx context.Context, user *User) error
    Update(ctx context.Context, user *User) error
    Delete(ctx context.Context, id string) error
}

// Compose when needed
type UserStore interface {
    UserReader
    UserWriter
}
```

## Consumer-Defined Interfaces

```go
// In package "notifier" — defines only what it needs
package notifier

type UserFinder interface {
    Get(ctx context.Context, id string) (*User, error)
}

type Service struct {
    users UserFinder // accepts the narrow interface
}

func (s *Service) NotifyUser(ctx context.Context, userID string) error {
    user, err := s.users.Get(ctx, userID)
    if err != nil {
        return fmt.Errorf("finding user: %w", err)
    }
    return s.send(user.Email, "Hello!")
}
```

## Functional Options Pattern

```go
type Server struct {
    addr    string
    timeout time.Duration
    logger  *slog.Logger
    tls     *tls.Config
}

type Option func(*Server)

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func WithLogger(l *slog.Logger) Option {
    return func(s *Server) { s.logger = l }
}

func WithTLS(cfg *tls.Config) Option {
    return func(s *Server) { s.tls = cfg }
}

func NewServer(addr string, opts ...Option) *Server {
    s := &Server{
        addr:    addr,
        timeout: 30 * time.Second,             // sensible default
        logger:  slog.Default(),                // sensible default
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// Usage
srv := NewServer(":8080",
    WithTimeout(10*time.Second),
    WithLogger(myLogger),
)
```

## Standard Library Interfaces to Know

| Interface | Package | Methods | Use When |
|-----------|---------|---------|----------|
| `io.Reader` | `io` | `Read([]byte) (int, error)` | Anything that produces bytes |
| `io.Writer` | `io` | `Write([]byte) (int, error)` | Anything that consumes bytes |
| `io.Closer` | `io` | `Close() error` | Resources needing cleanup |
| `fmt.Stringer` | `fmt` | `String() string` | Human-readable representation |
| `error` | builtin | `Error() string` | Custom error types |
| `sort.Interface` | `sort` | `Len, Less, Swap` | Custom sort orders |
| `http.Handler` | `net/http` | `ServeHTTP(w, r)` | HTTP request handling |
| `encoding.TextMarshaler` | `encoding` | `MarshalText() ([]byte, error)` | Text serialization |
| `json.Marshaler` | `encoding/json` | `MarshalJSON() ([]byte, error)` | Custom JSON encoding |
| `context.Context` | `context` | `Deadline, Done, Err, Value` | Cancellation & request scope |
