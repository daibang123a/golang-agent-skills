---
name: go-testing-guidelines
description: >
  Go testing best practices with 30+ rules across 6 categories. Covers
  table-driven tests, mocking, integration testing, benchmarks, fuzz testing,
  and test helpers. Use when writing tests, reviewing test code, setting up
  CI testing, or measuring coverage. Triggers: "Write tests", "Table-driven test",
  "Benchmark this", "Fuzz test", "Integration test", "Mock this dependency".
---

# Go Testing Guidelines

Comprehensive testing best practices for Go. 30+ rules covering unit tests, integration tests, benchmarks, fuzzing, and test organization.

## How It Works

1. Agent identifies the testing need (unit, integration, benchmark, fuzz)
2. Agent applies the appropriate patterns from this skill
3. Agent generates test code following Go conventions
4. Agent ensures proper cleanup, parallelism, and naming

## Rules

### 1. Table-Driven Tests (Critical)

| # | Rule | Description |
|---|------|-------------|
| TD1 | **Use table-driven tests for multiple cases** | Define test cases as a slice of structs. Each case has a name and inputs/expected outputs. |
| TD2 | **Name test cases descriptively** | `"empty input"`, `"negative number"`, `"unicode string"` — names appear in test output. |
| TD3 | **Use t.Run for subtests** | Enables running individual cases: `go test -run TestFoo/empty_input`. |
| TD4 | **Run subtests in parallel when safe** | Call `t.Parallel()` in subtests for independent test cases. Capture loop variable. |
| TD5 | **Include error cases** | Always test error paths, edge cases, and boundary conditions. |

```go
func TestParseAge(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int
        wantErr bool
    }{
        {name: "valid age", input: "25", want: 25},
        {name: "zero", input: "0", want: 0},
        {name: "negative", input: "-1", wantErr: true},
        {name: "not a number", input: "abc", wantErr: true},
        {name: "empty string", input: "", wantErr: true},
        {name: "overflow", input: "999999", wantErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            got, err := ParseAge(tt.input)
            if tt.wantErr {
                if err == nil {
                    t.Errorf("ParseAge(%q) expected error, got %d", tt.input, got)
                }
                return
            }
            if err != nil {
                t.Fatalf("ParseAge(%q) unexpected error: %v", tt.input, err)
            }
            if got != tt.want {
                t.Errorf("ParseAge(%q) = %d, want %d", tt.input, got, tt.want)
            }
        })
    }
}
```

### 2. Mocking & Interfaces (High)

| # | Rule | Description |
|---|------|-------------|
| MK1 | **Define interfaces at the consumer** | The test file or consumer package defines the interface it needs. |
| MK2 | **Use interface-based test doubles** | Create mock structs that implement the interface. No framework needed for simple cases. |
| MK3 | **Keep mocks simple** | A mock should only implement what the test needs. Use function fields for flexible behavior. |
| MK4 | **Use testify/mock for complex assertions** | When you need call counting, argument matching, or ordered expectations. |
| MK5 | **Prefer fakes over mocks for I/O** | In-memory databases, fake HTTP servers (`httptest.Server`) are more reliable than mocks. |

```go
// Simple function-field mock
type mockStore struct {
    GetFunc    func(ctx context.Context, id string) (*User, error)
    CreateFunc func(ctx context.Context, u *User) error
}

func (m *mockStore) Get(ctx context.Context, id string) (*User, error) {
    return m.GetFunc(ctx, id)
}

func (m *mockStore) Create(ctx context.Context, u *User) error {
    return m.CreateFunc(ctx, u)
}

func TestService_GetUser(t *testing.T) {
    store := &mockStore{
        GetFunc: func(_ context.Context, id string) (*User, error) {
            if id == "123" {
                return &User{ID: "123", Name: "Alice"}, nil
            }
            return nil, ErrNotFound
        },
    }

    svc := NewService(store)
    user, err := svc.GetUser(context.Background(), "123")
    if err != nil {
        t.Fatal(err)
    }
    if user.Name != "Alice" {
        t.Errorf("got name %q, want Alice", user.Name)
    }
}
```

### 3. Integration Testing (High)

| # | Rule | Description |
|---|------|-------------|
| IT1 | **Use build tags for integration tests** | `//go:build integration` to separate from unit tests. |
| IT2 | **Use testcontainers-go** | Spin up real databases, Redis, Kafka in Docker for integration tests. |
| IT3 | **Clean up resources** | Use `t.Cleanup()` to ensure containers and connections are closed. |
| IT4 | **Use TestMain for shared setup** | One-time setup/teardown for the test binary using `TestMain(m *testing.M)`. |
| IT5 | **Use httptest.Server for HTTP** | Real HTTP server on localhost for testing HTTP clients and handlers. |
| IT6 | **Isolate test data** | Each test creates its own data. Never depend on data from another test. |

```go
//go:build integration

func TestUserRepository_Integration(t *testing.T) {
    ctx := context.Background()

    // Start PostgreSQL container
    container, err := postgres.Run(ctx,
        "postgres:16-alpine",
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
    )
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() { container.Terminate(ctx) })

    connStr, err := container.ConnectionString(ctx, "sslmode=disable")
    if err != nil {
        t.Fatal(err)
    }

    db, err := sql.Open("pgx", connStr)
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() { db.Close() })

    // Run migrations
    runMigrations(t, db)

    repo := NewUserRepository(db)

    t.Run("create and get", func(t *testing.T) {
        user := &User{Name: "Alice", Email: "alice@test.com"}
        err := repo.Create(ctx, user)
        if err != nil {
            t.Fatal(err)
        }

        got, err := repo.Get(ctx, user.ID)
        if err != nil {
            t.Fatal(err)
        }
        if got.Name != "Alice" {
            t.Errorf("got name %q, want Alice", got.Name)
        }
    })
}
```

### 4. Benchmarking (Medium)

| # | Rule | Description |
|---|------|-------------|
| BM1 | **Use b.ReportAllocs()** | Always report allocations in benchmarks. |
| BM2 | **Prevent compiler optimizations** | Assign results to a package-level variable to prevent dead code elimination. |
| BM3 | **Use b.ResetTimer() after setup** | Reset the timer after expensive setup that shouldn't be measured. |
| BM4 | **Benchmark with realistic data** | Use production-like input sizes. |
| BM5 | **Use benchstat for comparison** | `benchstat old.txt new.txt` for statistically significant comparisons. |

```go
var result int // prevent optimization

func BenchmarkFibonacci(b *testing.B) {
    b.ReportAllocs()
    var r int
    for i := 0; i < b.N; i++ {
        r = Fibonacci(20)
    }
    result = r
}

// Sub-benchmarks for different sizes
func BenchmarkSort(b *testing.B) {
    for _, size := range []int{100, 1000, 10000} {
        b.Run(fmt.Sprintf("size=%d", size), func(b *testing.B) {
            b.ReportAllocs()
            data := generateData(size)
            b.ResetTimer()
            for i := 0; i < b.N; i++ {
                sorted := make([]int, len(data))
                copy(sorted, data)
                sort.Ints(sorted)
            }
        })
    }
}
```

### 5. Fuzz Testing (Medium)

| # | Rule | Description |
|---|------|-------------|
| FZ1 | **Fuzz input validation and parsers** | Fuzzing is most valuable for code that processes untrusted input. |
| FZ2 | **Add seed corpus** | Use `f.Add()` with representative inputs to guide the fuzzer. |
| FZ3 | **Check for panics, not just errors** | Fuzz tests should catch panics that indicate bugs. |
| FZ4 | **Run fuzzing in CI with a time limit** | `go test -fuzz=. -fuzztime=60s`. |

```go
func FuzzParseJSON(f *testing.F) {
    // Seed corpus
    f.Add([]byte(`{"name":"alice","age":30}`))
    f.Add([]byte(`{}`))
    f.Add([]byte(`[]`))
    f.Add([]byte(`null`))
    f.Add([]byte(``))

    f.Fuzz(func(t *testing.T, data []byte) {
        var user User
        err := json.Unmarshal(data, &user)
        if err != nil {
            return // invalid input is fine
        }

        // Round-trip: marshal and unmarshal again
        encoded, err := json.Marshal(user)
        if err != nil {
            t.Fatalf("failed to marshal valid user: %v", err)
        }

        var user2 User
        if err := json.Unmarshal(encoded, &user2); err != nil {
            t.Fatalf("failed to unmarshal re-encoded user: %v", err)
        }
    })
}
```

### 6. Test Helpers & Organization (Medium)

| # | Rule | Description |
|---|------|-------------|
| TH1 | **Use t.Helper() in helper functions** | Marks the function as a helper so failures report the caller's line. |
| TH2 | **Use golden files for complex output** | Store expected output in `testdata/` directory. Update with `-update` flag. |
| TH3 | **Use t.Cleanup() instead of defer** | Cleanup functions run after the test and all its subtests. |
| TH4 | **Use t.TempDir() for temp files** | Automatically cleaned up after the test. |
| TH5 | **Put test fixtures in testdata/** | The `testdata` directory is ignored by `go build` but available to tests. |

```go
func assertEqual[T comparable](t *testing.T, got, want T) {
    t.Helper()
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}

func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()
    db, err := sql.Open("sqlite3", ":memory:")
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() { db.Close() })
    return db
}

// Golden file pattern
func TestRender(t *testing.T) {
    got := Render(input)

    golden := filepath.Join("testdata", t.Name()+".golden")
    if *update {
        os.WriteFile(golden, got, 0644)
    }
    want, _ := os.ReadFile(golden)

    if !bytes.Equal(got, want) {
        t.Errorf("output mismatch (run with -update to update golden files)")
    }
}
```

## Quick Reference

Run the test analysis script:

```bash
bash skills/go-testing-guidelines/scripts/test-coverage.sh /path/to/project
```
