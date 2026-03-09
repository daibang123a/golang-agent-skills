# SQLX Patterns for Go

SQLX extends `database/sql` with struct scanning, named parameters, and convenience methods.

## Setup

```go
import "github.com/jmoiron/sqlx"

db, err := sqlx.Connect("pgx", dsn)
```

## Struct Scanning

```go
type User struct {
    ID        string    `db:"id"`
    Name      string    `db:"name"`
    Email     string    `db:"email"`
    CreatedAt time.Time `db:"created_at"`
}

// Get single row
var user User
err := db.GetContext(ctx, &user, `SELECT * FROM users WHERE id = $1`, id)

// Get multiple rows
var users []User
err := db.SelectContext(ctx, &users, `SELECT * FROM users WHERE role = $1`, "admin")
```

## Named Queries

```go
user := User{Name: "Alice", Email: "alice@example.com"}
_, err := db.NamedExecContext(ctx,
    `INSERT INTO users (name, email) VALUES (:name, :email)`, user)
```

## In-Clause Expansion

```go
ids := []string{"id1", "id2", "id3"}
query, args, err := sqlx.In(`SELECT * FROM users WHERE id IN (?)`, ids)
query = db.Rebind(query) // Convert ? to $1, $2... for PostgreSQL

var users []User
err = db.SelectContext(ctx, &users, query, args...)
```

## Transaction Helper

```go
func WithSQLXTx(ctx context.Context, db *sqlx.DB, fn func(*sqlx.Tx) error) error {
    tx, err := db.BeginTxx(ctx, nil)
    if err != nil {
        return err
    }
    if err := fn(tx); err != nil {
        tx.Rollback()
        return err
    }
    return tx.Commit()
}
```
