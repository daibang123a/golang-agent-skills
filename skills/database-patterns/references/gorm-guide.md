# GORM Best Practices for Go

## Setup

```go
import (
    "gorm.io/gorm"
    "gorm.io/driver/postgres"
)

db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
    Logger:                 logger.Default.LogMode(logger.Warn),
    SkipDefaultTransaction: true, // Disable wrapping every query in a transaction
    PrepareStmt:            true, // Cache prepared statements
})

// Access underlying sql.DB for pool config
sqlDB, _ := db.DB()
sqlDB.SetMaxOpenConns(25)
sqlDB.SetMaxIdleConns(10)
sqlDB.SetConnMaxLifetime(30 * time.Minute)
```

## Model Design

```go
type User struct {
    ID        uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
    Name      string    `gorm:"not null"`
    Email     string    `gorm:"uniqueIndex;not null"`
    Role      string    `gorm:"default:'viewer'"`
    Orders    []Order   `gorm:"foreignKey:UserID"`      // has many
    Profile   *Profile  `gorm:"foreignKey:UserID"`      // has one
    CreatedAt time.Time
    UpdatedAt time.Time
    DeletedAt gorm.DeletedAt `gorm:"index"` // soft delete
}
```

## Common Pitfalls

| Pitfall | Problem | Fix |
|---------|---------|-----|
| N+1 queries | Loading relations one by one | Use `Preload("Orders")` or `Joins()` |
| Select * | Loading unnecessary columns | Use `Select("id", "name")` |
| No index on foreign keys | Slow JOINs | Add `gorm:"index"` to FK columns |
| Missing context | Can't cancel long queries | Always use `db.WithContext(ctx)` |
| Auto-migrate in production | Dangerous DDL changes | Use proper migration tools |

## Query Patterns

```go
// Always use context
var users []User
db.WithContext(ctx).Where("role = ?", "admin").Find(&users)

// Preload to avoid N+1
db.WithContext(ctx).Preload("Orders").First(&user, "id = ?", id)

// Select specific columns
db.WithContext(ctx).Select("id", "name", "email").Find(&users)

// Scopes for reusable queries
func Active(db *gorm.DB) *gorm.DB {
    return db.Where("deleted_at IS NULL AND active = true")
}
db.Scopes(Active).Find(&users)
```

## When to Use GORM vs database/sql

| Use Case | GORM | database/sql + SQLX |
|----------|------|---------------------|
| Rapid prototyping | ✅ | |
| Simple CRUD apps | ✅ | |
| Complex queries / CTEs | | ✅ |
| Performance-critical paths | | ✅ |
| Full control over SQL | | ✅ |
| Team familiar with ORMs | ✅ | |
