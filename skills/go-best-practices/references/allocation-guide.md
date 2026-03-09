# Go Memory Allocation Guide

## Escape Analysis

Go's compiler decides whether a variable lives on the stack or heap. Use
`go build -gcflags="-m"` to see escape analysis decisions.

### Common Escape Triggers

1. **Returning a pointer to a local variable** — the variable escapes to the heap
2. **Storing a pointer in an interface** — interface values may cause heap allocation
3. **Closures capturing local variables** — captured variables escape
4. **Sending pointers to channels** — the pointed-to value must outlive the goroutine
5. **Slice/map growth beyond initial capacity** — reallocation moves data to heap

### Reducing Allocations

```go
// BAD: allocates on every call
func NewBuffer() *bytes.Buffer {
    return &bytes.Buffer{}
}

// GOOD: use sync.Pool for hot-path allocations
var bufPool = sync.Pool{
    New: func() any { return new(bytes.Buffer) },
}

func GetBuffer() *bytes.Buffer {
    return bufPool.Get().(*bytes.Buffer)
}

func PutBuffer(b *bytes.Buffer) {
    b.Reset()
    bufPool.Put(b)
}
```

### Pre-allocation Patterns

```go
// BAD: grows dynamically, multiple allocations
var result []string
for _, item := range items {
    result = append(result, item.Name)
}

// GOOD: pre-allocate with known capacity
result := make([]string, 0, len(items))
for _, item := range items {
    result = append(result, item.Name)
}

// BAD: map grows and rehashes
m := make(map[string]int)

// GOOD: pre-allocate map capacity
m := make(map[string]int, expectedSize)
```

## Profiling Allocations

```bash
# CPU profile
go test -cpuprofile=cpu.prof -bench=.
go tool pprof cpu.prof

# Memory profile
go test -memprofile=mem.prof -bench=.
go tool pprof -alloc_space mem.prof

# Trace
go test -trace=trace.out -bench=.
go tool trace trace.out
```

## Benchmarking Allocation

```go
func BenchmarkAllocation(b *testing.B) {
    b.ReportAllocs()
    for i := 0; i < b.N; i++ {
        // code under test
    }
}
```

Output includes `allocs/op` and `B/op` metrics. Target zero allocations on hot paths.
