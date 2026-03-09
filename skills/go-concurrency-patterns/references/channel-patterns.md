# Go Channel Patterns Reference

## Channel Axioms

| Operation | nil channel | closed channel | open channel |
|-----------|-------------|----------------|--------------|
| Send | Block forever | **PANIC** | Send or block |
| Receive | Block forever | Zero value, false | Receive or block |
| Close | **PANIC** | **PANIC** | Close |

## Generator Pattern

A function that returns a channel and populates it from a goroutine.

```go
func Generate(ctx context.Context, values ...int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for _, v := range values {
            select {
            case out <- v:
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}
```

## Tee Channel

Split one channel into two identical output channels.

```go
func Tee[T any](ctx context.Context, in <-chan T) (<-chan T, <-chan T) {
    out1, out2 := make(chan T), make(chan T)
    go func() {
        defer close(out1)
        defer close(out2)
        for val := range in {
            // Use local copies for the select to avoid
            // sending to one but not the other
            o1, o2 := out1, out2
            for i := 0; i < 2; i++ {
                select {
                case o1 <- val:
                    o1 = nil
                case o2 <- val:
                    o2 = nil
                case <-ctx.Done():
                    return
                }
            }
        }
    }()
    return out1, out2
}
```

## Bridge Channel

Flatten a channel of channels into a single channel.

```go
func Bridge[T any](ctx context.Context, chanStream <-chan <-chan T) <-chan T {
    out := make(chan T)
    go func() {
        defer close(out)
        for {
            var stream <-chan T
            select {
            case maybe, ok := <-chanStream:
                if !ok { return }
                stream = maybe
            case <-ctx.Done():
                return
            }
            for val := range stream {
                select {
                case out <- val:
                case <-ctx.Done():
                    return
                }
            }
        }
    }()
    return out
}
```

## Timeout Pattern

```go
func DoWithTimeout(ctx context.Context, timeout time.Duration, fn func() (string, error)) (string, error) {
    ctx, cancel := context.WithTimeout(ctx, timeout)
    defer cancel()

    type result struct {
        val string
        err error
    }
    ch := make(chan result, 1) // buffered to prevent goroutine leak

    go func() {
        v, err := fn()
        ch <- result{v, err}
    }()

    select {
    case res := <-ch:
        return res.val, res.err
    case <-ctx.Done():
        return "", ctx.Err()
    }
}
```

## Heartbeat Pattern

Goroutine sends periodic heartbeats to prove it's alive.

```go
func WorkWithHeartbeat(ctx context.Context, interval time.Duration) (<-chan struct{}, <-chan int) {
    heartbeat := make(chan struct{})
    results := make(chan int)

    go func() {
        defer close(heartbeat)
        defer close(results)

        ticker := time.NewTicker(interval)
        defer ticker.Stop()

        for i := 0; ; i++ {
            select {
            case <-ctx.Done():
                return
            case <-ticker.C:
                select {
                case heartbeat <- struct{}{}:
                default: // don't block on heartbeat
                }
            case results <- i:
            }
        }
    }()

    return heartbeat, results
}
```
