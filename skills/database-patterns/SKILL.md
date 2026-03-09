---
name: database-patterns
description: >
  Go database access patterns and best practices. Covers database/sql, SQLX,
  GORM, connection pooling, transactions, migrations, and testing. Use when
  setting up database connections, writing queries, implementing repository
  patterns, or optimizing database performance. Triggers: "Database setup",
  "SQL in Go", "Connection pooling", "Database migration", "Repository pattern",
  "GORM", "SQLX", "Transaction handling".
---

# Go Database Patterns

Production-grade database access patterns for Go. Covers connection management, query patterns, transactions, migrations, and testing.

## How It Works

1. Agent identifies the database need (setup, query, migration, optimization)
2. Agent applies the appropriate pattern using the right abstraction level
3. Agent ensures proper connection management, error handling, and resource cleanup
4. Agent generates tests with appropriate mocking or containerized databases

## Rules

### 1. Connection Management (Critical)

| # | Rule | Description |
|---|------|-------------|
| CM1 | **Configure pool limits** | Set `MaxOpenConns`, `MaxIdleConns`, `ConnMaxLifetime`, `ConnMaxIdleTime`. |
| CM2 | **Always pass context** | Use `QueryContext`, `ExecContext`, `PrepareContext` — never the non-context variants. |
| CM3 | **Close rows** | Always `defer rows.Close()` immediately after `Query()`. |
| CM4 | **Ping on startup** | Call `db.PingContext(ctx)` to verify the connection before serving traffic. |
| CM5 | **Use connection string builder** | Don't concatenate connection strings. Use the driver's config builder. |

```go
func Connect(ctx context.Context, dsn string) (*sql.DB, error) {
    db, err := sql.Open("pgx", dsn)
    if err != nil {
        return nil, fmt.Errorf("opening database: %w", err)
    }

    // Connection pool settings
    db.SetMaxOpenConns(25)                 // Max concurrent connections
    db.SetMaxIdleConns(10)                 // Keep idle connections ready
    db.SetConnMaxLifetime(30 * time.Minute) // Recycle connections
    db.SetConnMaxIdleTime(5 * time.Minute)  // Close idle connections

    // Verify connection
    if err := db.PingContext(ctx); err != nil {
        db.Close()
        return nil, fmt.Errorf("pinging database: %w", err)
    }

    return db, nil
}
```

### 2. Repository Pattern (Critical)

| # | Rule | Description |
|---|------|-------------|
| RP1 | **Define repository interface at the consumer** | The service package defines what it needs from the repository. |
| RP2 | **Accept context as first parameter** | Every repository method takes `context.Context`. |
| RP3 | **Return domain types, not DB types** | Map between `sql.NullString` and `*string` at the repository boundary. |
| RP4 | **Handle sql.ErrNoRows** | Map to a domain-specific `ErrNotFound`. Don't leak `sql.ErrNoRows`. |
| RP5 | **Use prepared statements for repeated queries** | `db.PrepareContext()` once, then reuse. |

```go
// Domain layer — no database dependencies
package domain

type User struct {
    ID    string
    Name  string
    Email string
}

type UserRepository interface {
    Get(ctx context.Context, id string) (*User, error)
    List(ctx context.Context, limit, offset int) ([]*User, error)
    Create(ctx context.Context, user *User) error
    Update(ctx context.Context, user *User) error
    Delete(ctx context.Context, id string) error
}

var ErrNotFound = errors.New("not found")
```

```go
// PostgreSQL implementation
package postgres

type userRepository struct {
    db *sql.DB
}

func NewUserRepository(db *sql.DB) domain.UserRepository {
    return &userRepository{db: db}
}

func (r *userRepository) Get(ctx context.Context, id string) (*domain.User, error) {
    var u domain.User
    err := r.db.QueryRowContext(ctx,
        `SELECT id, name, email FROM users WHERE id = $1`, id,
    ).Scan(&u.ID, &u.Name, &u.Email)

    if errors.Is(err, sql.ErrNoRows) {
        return nil, domain.ErrNotFound
    }
    if err != nil {
        return nil, fmt.Errorf("querying user %s: %w", id, err)
    }
    return &u, nil
}

func (r *userRepository) Create(ctx context.Context, user *domain.User) error {
    _, err := r.db.ExecContext(ctx,
        `INSERT INTO users (id, name, email) VALUES ($1, $2, $3)`,
        user.ID, user.Name, user.Email,
    )
    if err != nil {
        return fmt.Errorf("inserting user: %w", err)
    }
    return nil
}

func (r *userRepository) List(ctx context.Context, limit, offset int) ([]*domain.User, error) {
    rows, err := r.db.QueryContext(ctx,
        `SELECT id, name, email FROM users ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
        limit, offset,
    )
    if err != nil {
        return nil, fmt.Errorf("listing users: %w", err)
    }
    defer rows.Close()

    var users []*domain.User
    for rows.Next() {
        var u domain.User
        if err := rows.Scan(&u.ID, &u.Name, &u.Email); err != nil {
            return nil, fmt.Errorf("scanning user: %w", err)
        }
        users = append(users, &u)
    }
    return users, rows.Err()
}
```

### 3. Transaction Management (High)

| # | Rule | Description |
|---|------|-------------|
| TX1 | **Use a transaction helper** | Wrap begin/commit/rollback in a helper to prevent missed rollbacks. |
| TX2 | **Rollback on error, commit on success** | Use defer + named return for automatic rollback. |
| TX3 | **Set isolation level when needed** | Use `sql.TxOptions{Isolation: sql.LevelSerializable}` for strict consistency. |
| TX4 | **Keep transactions short** | Don't do network calls or heavy computation inside a transaction. |
| TX5 | **Implement retry for serialization failures** | PostgreSQL `40001` errors should be retried. |

```go
// Transaction helper — automatic rollback on error
func WithTx(ctx context.Context, db *sql.DB, fn func(*sql.Tx) error) error {
    tx, err := db.BeginTx(ctx, nil)
    if err != nil {
        return fmt.Errorf("beginning transaction: %w", err)
    }

    if err := fn(tx); err != nil {
        if rbErr := tx.Rollback(); rbErr != nil {
            return fmt.Errorf("rollback failed: %v (original: %w)", rbErr, err)
        }
        return err
    }

    return tx.Commit()
}

// Usage
func (r *orderRepository) CreateOrder(ctx context.Context, order *Order) error {
    return WithTx(ctx, r.db, func(tx *sql.Tx) error {
        // Insert order
        _, err := tx.ExecContext(ctx,
            `INSERT INTO orders (id, user_id, total) VALUES ($1, $2, $3)`,
            order.ID, order.UserID, order.Total,
        )
        if err != nil {
            return fmt.Errorf("inserting order: %w", err)
        }

        // Insert order items
        for _, item := range order.Items {
            _, err := tx.ExecContext(ctx,
                `INSERT INTO order_items (order_id, product_id, qty, price)
                 VALUES ($1, $2, $3, $4)`,
                order.ID, item.ProductID, item.Quantity, item.Price,
            )
            if err != nil {
                return fmt.Errorf("inserting item: %w", err)
            }
        }

        // Update inventory
        for _, item := range order.Items {
            result, err := tx.ExecContext(ctx,
                `UPDATE products SET stock = stock - $1
                 WHERE id = $2 AND stock >= $1`,
                item.Quantity, item.ProductID,
            )
            if err != nil {
                return fmt.Errorf("updating stock: %w", err)
            }
            rows, _ := result.RowsAffected()
            if rows == 0 {
                return fmt.Errorf("insufficient stock for product %s", item.ProductID)
            }
        }

        return nil
    })
}
```

### 4. Migration Strategies (Medium)

| # | Rule | Description |
|---|------|-------------|
| MG1 | **Use a migration tool** | `golang-migrate/migrate`, `pressly/goose`, or `atlas`. |
| MG2 | **Version migrations sequentially** | `001_create_users.up.sql`, `001_create_users.down.sql`. |
| MG3 | **Always write down migrations** | Every `up` must have a corresponding `down` for rollback. |
| MG4 | **Test migrations** | Run up and down in CI to verify reversibility. |
| MG5 | **Use transactions in migrations** | Wrap DDL in transactions (PostgreSQL supports transactional DDL). |

```sql
-- 001_create_users.up.sql
BEGIN;

CREATE TABLE IF NOT EXISTS users (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    email      TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_email ON users (email);

COMMIT;
```

```sql
-- 001_create_users.down.sql
DROP TABLE IF EXISTS users;
```

### 5. Query Optimization (Medium)

| # | Rule | Description |
|---|------|-------------|
| QO1 | **Use EXPLAIN ANALYZE** | Check query plans for sequential scans on large tables. |
| QO2 | **Batch inserts** | Use `COPY` or multi-value `INSERT` instead of one-by-one. |
| QO3 | **Use connection pooling** | PgBouncer or built-in `database/sql` pool for connection reuse. |
| QO4 | **Index foreign keys** | Always index columns used in `JOIN` and `WHERE` clauses. |
| QO5 | **Use CTEs for complex queries** | Common Table Expressions improve readability and can be optimized. |

```go
// Batch insert using COPY (pgx)
func (r *repo) BulkInsertUsers(ctx context.Context, users []*User) error {
    rows := make([][]any, len(users))
    for i, u := range users {
        rows[i] = []any{u.ID, u.Name, u.Email}
    }

    _, err := r.pool.CopyFrom(ctx,
        pgx.Identifier{"users"},
        []string{"id", "name", "email"},
        pgx.CopyFromRows(rows),
    )
    return err
}
```

### 6. Testing (Medium)

| # | Rule | Description |
|---|------|-------------|
| DT1 | **Use testcontainers for integration** | Real database in Docker for accurate tests. |
| DT2 | **Use sqlmock for unit tests** | Mock SQL interface when testing service logic. |
| DT3 | **Isolate test data** | Each test uses its own data. Use transactions that rollback after each test. |

```go
// Test helper: rollback after each test
func setupTestTx(t *testing.T, db *sql.DB) *sql.Tx {
    t.Helper()
    tx, err := db.Begin()
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() { tx.Rollback() })
    return tx
}
```

For SQLX patterns, see `references/sqlx-patterns.md`.
For GORM best practices, see `references/gorm-guide.md`.
