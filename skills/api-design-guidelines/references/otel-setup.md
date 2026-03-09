# OpenTelemetry Setup for Go Services

## Dependencies

```bash
go get go.opentelemetry.io/otel
go get go.opentelemetry.io/otel/sdk
go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp
go get go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp
```

## Initialize Tracer

```go
package observability

import (
    "context"

    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

func InitTracer(ctx context.Context, serviceName, version string) (func(context.Context) error, error) {
    exporter, err := otlptracehttp.New(ctx)
    if err != nil {
        return nil, err
    }

    res, err := resource.Merge(
        resource.Default(),
        resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceName(serviceName),
            semconv.ServiceVersion(version),
        ),
    )
    if err != nil {
        return nil, err
    }

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
        sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(0.1))),
    )

    otel.SetTracerProvider(tp)
    otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{},
        propagation.Baggage{},
    ))

    return tp.Shutdown, nil
}
```

## HTTP Middleware

```go
import "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"

// Wrap your handler
handler := otelhttp.NewHandler(mux, "my-server")
```

## Custom Spans

```go
import "go.opentelemetry.io/otel"

var tracer = otel.Tracer("myservice/repository")

func (r *repo) GetUser(ctx context.Context, id string) (*User, error) {
    ctx, span := tracer.Start(ctx, "repository.GetUser")
    defer span.End()

    span.SetAttributes(attribute.String("user.id", id))

    // ... query database

    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return nil, err
    }
    return user, nil
}
```

## Structured Logging with Trace Context

```go
import "log/slog"

func logWithTrace(ctx context.Context, logger *slog.Logger, msg string, attrs ...slog.Attr) {
    span := trace.SpanFromContext(ctx)
    if span.SpanContext().IsValid() {
        attrs = append(attrs,
            slog.String("trace_id", span.SpanContext().TraceID().String()),
            slog.String("span_id", span.SpanContext().SpanID().String()),
        )
    }
    logger.LogAttrs(ctx, slog.LevelInfo, msg, attrs...)
}
```
