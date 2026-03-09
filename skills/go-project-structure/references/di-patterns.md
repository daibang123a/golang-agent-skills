# Dependency Injection Patterns in Go

## Constructor Injection (Recommended)

```go
type OrderService struct {
    repo   OrderRepository
    mailer Mailer
    logger *slog.Logger
}

func NewOrderService(repo OrderRepository, mailer Mailer, logger *slog.Logger) *OrderService {
    return &OrderService{repo: repo, mailer: mailer, logger: logger}
}
```

## Functional Options for Optional Dependencies

```go
type Server struct {
    db     *sql.DB
    cache  Cache
    logger *slog.Logger
    tracer trace.Tracer
}

type Option func(*Server)

func WithCache(c Cache) Option       { return func(s *Server) { s.cache = c } }
func WithLogger(l *slog.Logger) Option { return func(s *Server) { s.logger = l } }
func WithTracer(t trace.Tracer) Option { return func(s *Server) { s.tracer = t } }

func NewServer(db *sql.DB, opts ...Option) *Server {
    s := &Server{
        db:     db,
        logger: slog.Default(),
        cache:  noopCache{},
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

## Wire (Compile-Time DI)

Google Wire generates dependency injection code at compile time.

```go
// wire.go
//go:build wireinject

package main

import "github.com/google/wire"

func InitializeApp() (*App, error) {
    wire.Build(
        config.Load,
        database.Connect,
        postgres.NewUserRepository,
        service.NewUserService,
        handler.New,
        NewApp,
    )
    return nil, nil
}
```

Run `wire` to generate `wire_gen.go` with the actual wiring code.

## Manual Wiring in main.go (Simple Projects)

```go
func run(ctx context.Context) error {
    cfg := config.MustLoad()

    db, err := database.Connect(ctx, cfg.DatabaseURL)
    if err != nil { return err }
    defer db.Close()

    // Wire dependencies manually
    userRepo := postgres.NewUserRepository(db)
    orderRepo := postgres.NewOrderRepository(db)

    userSvc := service.NewUserService(userRepo)
    orderSvc := service.NewOrderService(orderRepo, userSvc)

    handler := handler.New(userSvc, orderSvc)
    return server.Run(ctx, cfg.Port, handler)
}
```

## When to Use What

| Approach | Best For | Complexity |
|----------|----------|------------|
| Constructor injection | Most projects | Low |
| Functional options | Optional deps, configuration | Medium |
| Google Wire | Large projects, many dependencies | Medium |
| Manual wiring in main | Small to medium projects | Low |
