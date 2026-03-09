# Domain-Driven Design Patterns in Go

## Layer Architecture

```
┌──────────────────────────────────────┐
│            HTTP / gRPC               │  ← handler (presentation)
├──────────────────────────────────────┤
│           Application                │  ← service (use cases)
├──────────────────────────────────────┤
│             Domain                   │  ← domain (entities, value objects, interfaces)
├──────────────────────────────────────┤
│          Infrastructure              │  ← repository, external APIs, messaging
└──────────────────────────────────────┘
```

Dependencies flow inward: Handler → Service → Domain ← Repository

## Domain Layer

```go
// internal/domain/user.go

// User is the core domain entity.
type User struct {
    ID        UserID
    Email     Email
    Name      string
    Role      Role
    CreatedAt time.Time
}

// UserID is a typed identifier for users.
type UserID string

// Email is a validated email value object.
type Email string

func NewEmail(raw string) (Email, error) {
    if !strings.Contains(raw, "@") {
        return "", fmt.Errorf("invalid email: %q", raw)
    }
    return Email(strings.ToLower(raw)), nil
}

// Role represents user authorization level.
type Role int

const (
    RoleViewer Role = iota
    RoleMember
    RoleAdmin
)

// CanManageUsers returns true if the role has user management permission.
func (r Role) CanManageUsers() bool {
    return r >= RoleAdmin
}
```

## Repository Interface (defined in domain)

```go
// internal/domain/repository.go

// UserRepository defines the persistence contract for users.
type UserRepository interface {
    Get(ctx context.Context, id UserID) (*User, error)
    GetByEmail(ctx context.Context, email Email) (*User, error)
    List(ctx context.Context, params ListParams) ([]*User, error)
    Save(ctx context.Context, user *User) error
    Delete(ctx context.Context, id UserID) error
}

type ListParams struct {
    Limit  int
    Offset int
    Role   *Role
}
```

## Service Layer (Application)

```go
// internal/service/user_service.go

type UserService struct {
    repo   domain.UserRepository
    events domain.EventPublisher
    logger *slog.Logger
}

func NewUserService(
    repo domain.UserRepository,
    events domain.EventPublisher,
    logger *slog.Logger,
) *UserService {
    return &UserService{repo: repo, events: events, logger: logger}
}

func (s *UserService) CreateUser(ctx context.Context, req CreateUserRequest) (*domain.User, error) {
    email, err := domain.NewEmail(req.Email)
    if err != nil {
        return nil, fmt.Errorf("invalid email: %w", err)
    }

    // Check for duplicate
    existing, err := s.repo.GetByEmail(ctx, email)
    if err != nil && !errors.Is(err, domain.ErrNotFound) {
        return nil, fmt.Errorf("checking existing user: %w", err)
    }
    if existing != nil {
        return nil, domain.ErrConflict
    }

    user := &domain.User{
        ID:        domain.UserID(uuid.NewString()),
        Email:     email,
        Name:      req.Name,
        Role:      domain.RoleViewer,
        CreatedAt: time.Now(),
    }

    if err := s.repo.Save(ctx, user); err != nil {
        return nil, fmt.Errorf("saving user: %w", err)
    }

    s.events.Publish(ctx, domain.UserCreatedEvent{UserID: user.ID})
    return user, nil
}
```

## Domain Events

```go
// internal/domain/events.go

type Event interface {
    EventName() string
}

type EventPublisher interface {
    Publish(ctx context.Context, event Event)
}

type UserCreatedEvent struct {
    UserID UserID
}

func (e UserCreatedEvent) EventName() string { return "user.created" }
```

## Value Objects vs Entities

| Concept | Identity? | Mutable? | Example |
|---------|-----------|----------|---------|
| Entity | Has unique ID | Yes | `User`, `Order` |
| Value Object | Defined by attributes | No (replace, don't modify) | `Email`, `Money`, `Address` |
| Aggregate Root | Entity + owns related entities | Yes | `Order` (owns `OrderItem`s) |

## Error Types

```go
// internal/domain/errors.go

var (
    ErrNotFound   = errors.New("not found")
    ErrConflict   = errors.New("conflict")
    ErrForbidden  = errors.New("forbidden")
    ErrValidation = errors.New("validation error")
)

type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s — %s", e.Field, e.Message)
}

func (e *ValidationError) Unwrap() error { return ErrValidation }
```
