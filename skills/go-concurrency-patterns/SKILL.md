---
name: go-concurrency-patterns
description: >
  Go concurrency patterns that scale. Covers goroutine lifecycle, channel
  patterns, sync primitives, context propagation, errgroup, and worker pools.
  Use when designing concurrent systems, building pipelines, debugging
  goroutine leaks, or implementing graceful shutdown. Triggers: "worker pool",
  "fan-out fan-in", "goroutine leak", "concurrent Go", "channel patterns",
  "parallel processing".
---

# Go Concurrency Patterns

Production-grade concurrency patterns for Go. Each pattern includes when to use it, the implementation, and common pitfalls.

## How It Works

1. Agent identifies the concurrency need from the task description
2. Agent selects the appropriate pattern(s) from this catalog
3. Agent implements the pattern with proper error handling and cancellation
4. Agent verifies goroutine lifecycle management (no leaks)

## Patterns

### 1. Worker Pool (Critical)

Bounded concurrency for processing a stream of work items. Controls resource usage.

**When to use:** Processing N items with at most M concurrent workers.

```go
func WorkerPool[T any, R any](
    ctx context.Context,
    items []T,
    workers int,
    process func(context.Context, T) (R, error),
) ([]R, error) {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(workers)

    var mu sync.Mutex
    results := make([]R, 0, len(items))

    for _, item := range items {
        g.Go(func() error {
            result, err := process(ctx, item)
            if err != nil {
                return err
            }
            mu.Lock()
            results = append(results, result)
            mu.Unlock()
            return nil
        })
    }

    if err := g.Wait(); err != nil {
        return nil, err
    }
    return results, nil
}
```

**Pitfalls:**
- Without `SetLimit`, all items start concurrently (not a pool)
- Results are unordered — use index-based collection if order matters
- First error cancels remaining work via errgroup context

### 2. Fan-Out / Fan-In (Critical)

Distribute work across multiple goroutines, then collect results.

```go
func FanOutFanIn[T any](
    ctx context.Context,
    input <-chan T,
    workers int,
    process func(context.Context, T) T,
) <-chan T {
    // Fan-out: create N worker channels
    channels := make([]<-chan T, workers)
    for i := 0; i < workers; i++ {
        channels[i] = worker(ctx, input, process)
    }

    // Fan-in: merge all worker channels into one
    return merge(ctx, channels...)
}

func worker[T any](
    ctx context.Context,
    input <-chan T,
    process func(context.Context, T) T,
) <-chan T {
    out := make(chan T)
    go func() {
        defer close(out)
        for item := range input {
            select {
            case out <- process(ctx, item):
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}

func merge[T any](ctx context.Context, channels ...<-chan T) <-chan T {
    var wg sync.WaitGroup
    out := make(chan T)

    output := func(ch <-chan T) {
        defer wg.Done()
        for item := range ch {
            select {
            case out <- item:
            case <-ctx.Done():
                return
            }
        }
    }

    wg.Add(len(channels))
    for _, ch := range channels {
        go output(ch)
    }

    go func() {
        wg.Wait()
        close(out)
    }()

    return out
}
```

### 3. Pipeline (High)

Chain processing stages, each running concurrently.

```go
// Stage is a pipeline processing stage
type Stage[T any] func(ctx context.Context, in <-chan T) <-chan T

// Pipeline connects stages sequentially
func Pipeline[T any](ctx context.Context, source <-chan T, stages ...Stage[T]) <-chan T {
    current := source
    for _, stage := range stages {
        current = stage(ctx, current)
    }
    return current
}

// Example stage: filter
func Filter[T any](predicate func(T) bool) Stage[T] {
    return func(ctx context.Context, in <-chan T) <-chan T {
        out := make(chan T)
        go func() {
            defer close(out)
            for item := range in {
                if predicate(item) {
                    select {
                    case out <- item:
                    case <-ctx.Done():
                        return
                    }
                }
            }
        }()
        return out
    }
}

// Example stage: transform
func Transform[T any](fn func(T) T) Stage[T] {
    return func(ctx context.Context, in <-chan T) <-chan T {
        out := make(chan T)
        go func() {
            defer close(out)
            for item := range in {
                select {
                case out <- fn(item):
                case <-ctx.Done():
                    return
                }
            }
        }()
        return out
    }
}
```

### 4. Semaphore (High)

Limit concurrent access to a resource.

```go
// Using a buffered channel as a semaphore
type Semaphore struct {
    ch chan struct{}
}

func NewSemaphore(max int) *Semaphore {
    return &Semaphore{ch: make(chan struct{}, max)}
}

func (s *Semaphore) Acquire(ctx context.Context) error {
    select {
    case s.ch <- struct{}{}:
        return nil
    case <-ctx.Done():
        return ctx.Err()
    }
}

func (s *Semaphore) Release() {
    <-s.ch
}

// Or use golang.org/x/sync/semaphore for weighted semaphore
```

### 5. Context-Based Cancellation Tree (High)

Propagate cancellation through a hierarchy of operations.

```go
func ProcessOrder(ctx context.Context, order Order) error {
    // Create a cancellable context for this order
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()

    g, ctx := errgroup.WithContext(ctx)

    // Parallel independent steps — any failure cancels all
    g.Go(func() error { return validateInventory(ctx, order) })
    g.Go(func() error { return authorizePayment(ctx, order) })
    g.Go(func() error { return checkFraud(ctx, order) })

    if err := g.Wait(); err != nil {
        return fmt.Errorf("order validation failed: %w", err)
    }

    // Sequential dependent steps
    if err := chargePayment(ctx, order); err != nil {
        return fmt.Errorf("payment failed: %w", err)
    }
    return shipOrder(ctx, order)
}
```

### 6. Or-Done Channel (Medium)

Read from a channel respecting cancellation without duplicating `select` logic.

```go
func OrDone[T any](ctx context.Context, ch <-chan T) <-chan T {
    out := make(chan T)
    go func() {
        defer close(out)
        for {
            select {
            case <-ctx.Done():
                return
            case v, ok := <-ch:
                if !ok {
                    return
                }
                select {
                case out <- v:
                case <-ctx.Done():
                    return
                }
            }
        }
    }()
    return out
}
```

### 7. Rate-Limited Concurrency (Medium)

Process items concurrently with a rate limit.

```go
func RateLimited[T any](
    ctx context.Context,
    items []T,
    rps float64,
    process func(context.Context, T) error,
) error {
    limiter := rate.NewLimiter(rate.Limit(rps), 1)

    g, ctx := errgroup.WithContext(ctx)
    for _, item := range items {
        if err := limiter.Wait(ctx); err != nil {
            return err
        }
        g.Go(func() error {
            return process(ctx, item)
        })
    }
    return g.Wait()
}
```

### 8. Publish/Subscribe (Medium)

In-process event bus with typed channels.

```go
type PubSub[T any] struct {
    mu   sync.RWMutex
    subs map[string][]chan T
}

func NewPubSub[T any]() *PubSub[T] {
    return &PubSub[T]{subs: make(map[string][]chan T)}
}

func (ps *PubSub[T]) Subscribe(topic string, buffer int) <-chan T {
    ch := make(chan T, buffer)
    ps.mu.Lock()
    ps.subs[topic] = append(ps.subs[topic], ch)
    ps.mu.Unlock()
    return ch
}

func (ps *PubSub[T]) Publish(topic string, msg T) {
    ps.mu.RLock()
    defer ps.mu.RUnlock()
    for _, ch := range ps.subs[topic] {
        select {
        case ch <- msg:
        default: // drop if subscriber is slow
        }
    }
}

func (ps *PubSub[T]) Close(topic string) {
    ps.mu.Lock()
    defer ps.mu.Unlock()
    for _, ch := range ps.subs[topic] {
        close(ch)
    }
    delete(ps.subs, topic)
}
```

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Fire-and-forget goroutines | No error handling, possible leaks | Use errgroup or track with WaitGroup |
| Unbounded goroutine creation | Resource exhaustion under load | Use worker pool or semaphore |
| Shared state without sync | Race conditions, data corruption | Use mutex, channels, or atomic |
| Ignoring context cancellation | Goroutines continue after caller exits | Always `select` on `ctx.Done()` |
| Closing channels from receiver | Panic: close of closed channel | Only the sender closes the channel |
| Using `time.After` in loops | Memory leak from timer accumulation | Use `time.NewTimer` and `Reset()` |

## Verification

Use `go test -race ./...` to detect race conditions.
Use `go.uber.org/goleak` in tests to detect goroutine leaks.

For detailed channel patterns, see `references/channel-patterns.md`.
