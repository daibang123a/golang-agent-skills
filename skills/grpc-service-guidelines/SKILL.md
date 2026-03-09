---
name: grpc-service-guidelines
description: >
  gRPC service design and implementation best practices for Go. Covers protobuf
  schema design, server/client implementation, interceptors, streaming, and
  error handling. Use when designing protobuf schemas, implementing gRPC servers
  or clients, or reviewing gRPC service code. Triggers: "gRPC service",
  "protobuf design", "gRPC interceptor", "streaming RPC", "gRPC error handling".
---

# gRPC Service Guidelines for Go

Production-grade gRPC service patterns for Go. Covers protobuf design, interceptors, streaming, and operational patterns.

## How It Works

1. Agent examines protobuf definitions and Go gRPC implementation
2. Agent applies rules by category in priority order
3. Agent suggests idiomatic Go patterns for gRPC services
4. Agent references supporting docs for advanced topics

## Rules

### 1. Protobuf Design (Critical)

| # | Rule | Description |
|---|------|-------------|
| PB1 | **Use proto3 syntax** | `syntax = "proto3";` — the default for all new services. |
| PB2 | **Version your packages** | `package myservice.v1;` with `option go_package = "gen/myservice/v1";`. |
| PB3 | **Never reuse field numbers** | Deleted fields: use `reserved 5, 6;`. Deleted names: use `reserved "old_name";`. |
| PB4 | **Use well-known types** | `google.protobuf.Timestamp`, `Duration`, `FieldMask`, `Empty`, `Struct`, `Any`. |
| PB5 | **Design for backward compatibility** | Add fields (never remove). Use `optional` for fields that may not be set. |
| PB6 | **Keep messages focused** | One request/response pair per RPC. Don't reuse messages across different RPCs. |
| PB7 | **Use enums with UNSPECIFIED=0** | First value should be `THING_UNSPECIFIED = 0;` as the default/unknown state. |
| PB8 | **Use FieldMask for partial updates** | `UpdateUserRequest { User user = 1; google.protobuf.FieldMask update_mask = 2; }`. |

```protobuf
syntax = "proto3";

package userservice.v1;

import "google/protobuf/timestamp.proto";
import "google/protobuf/field_mask.proto";

option go_package = "github.com/yourorg/myservice/gen/userservice/v1";

service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
  rpc UpdateUser(UpdateUserRequest) returns (UpdateUserResponse);
  rpc DeleteUser(DeleteUserRequest) returns (DeleteUserResponse);
}

message User {
  string id = 1;
  string name = 2;
  string email = 3;
  UserRole role = 4;
  google.protobuf.Timestamp created_at = 5;
  google.protobuf.Timestamp updated_at = 6;
}

enum UserRole {
  USER_ROLE_UNSPECIFIED = 0;
  USER_ROLE_ADMIN = 1;
  USER_ROLE_MEMBER = 2;
  USER_ROLE_VIEWER = 3;
}

message GetUserRequest {
  string id = 1;
}

message GetUserResponse {
  User user = 1;
}

message ListUsersRequest {
  int32 page_size = 1;
  string page_token = 2;
}

message ListUsersResponse {
  repeated User users = 1;
  string next_page_token = 2;
}

message UpdateUserRequest {
  User user = 1;
  google.protobuf.FieldMask update_mask = 2;
}
```

### 2. Server Implementation (High)

| # | Rule | Description |
|---|------|-------------|
| SV1 | **Register reflection service** | Enables `grpcurl` and other tools to discover your API. |
| SV2 | **Register health service** | Use `grpc_health_v1` for load balancer health checks. |
| SV3 | **Set max message size** | Default is 4MB. Increase explicitly if needed: `grpc.MaxRecvMsgSize(16 << 20)`. |
| SV4 | **Use keepalive parameters** | Prevent idle connections from being dropped by proxies. |
| SV5 | **Graceful stop** | Use `server.GracefulStop()` with a deadline, then `server.Stop()`. |

```go
func NewGRPCServer(svc *service.UserService) *grpc.Server {
    server := grpc.NewServer(
        grpc.MaxRecvMsgSize(16 << 20), // 16MB
        grpc.KeepaliveParams(keepalive.ServerParameters{
            MaxConnectionIdle: 5 * time.Minute,
            Time:              2 * time.Hour,
            Timeout:           20 * time.Second,
        }),
        grpc.ChainUnaryInterceptor(
            recovery.UnaryServerInterceptor(),
            logging.UnaryServerInterceptor(),
            auth.UnaryServerInterceptor(),
        ),
        grpc.ChainStreamInterceptor(
            recovery.StreamServerInterceptor(),
            logging.StreamServerInterceptor(),
        ),
    )

    pb.RegisterUserServiceServer(server, &userServer{svc: svc})
    reflection.Register(server)
    grpc_health_v1.RegisterHealthServer(server, health.NewServer())

    return server
}
```

### 3. Error Handling (High)

| # | Rule | Description |
|---|------|-------------|
| ER1 | **Use proper gRPC status codes** | `codes.NotFound`, `codes.InvalidArgument`, `codes.Internal`, etc. |
| ER2 | **Add error details** | Use `status.WithDetails()` for machine-readable error metadata. |
| ER3 | **Map domain errors to gRPC codes** | Create a mapping function: `domainErr → gRPC status`. |
| ER4 | **Never expose internal details** | Don't leak stack traces or internal errors to clients. Log them, return generic messages. |

```go
import (
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
    errdetails "google.golang.org/genproto/googleapis/rpc/errdetails"
)

func toGRPCError(err error) error {
    switch {
    case errors.Is(err, domain.ErrNotFound):
        return status.Error(codes.NotFound, "resource not found")
    case errors.Is(err, domain.ErrConflict):
        return status.Error(codes.AlreadyExists, "resource already exists")
    case errors.Is(err, domain.ErrValidation):
        // Rich error with field violations
        st := status.New(codes.InvalidArgument, "validation failed")
        var valErr *domain.ValidationError
        if errors.As(err, &valErr) {
            br := &errdetails.BadRequest{}
            for _, v := range valErr.Violations {
                br.FieldViolations = append(br.FieldViolations,
                    &errdetails.BadRequest_FieldViolation{
                        Field:       v.Field,
                        Description: v.Message,
                    })
            }
            st, _ = st.WithDetails(br)
        }
        return st.Err()
    default:
        return status.Error(codes.Internal, "internal error")
    }
}
```

### 4. Interceptors (Medium-High)

| # | Rule | Description |
|---|------|-------------|
| IC1 | **Use chain interceptors** | `grpc.ChainUnaryInterceptor()` for composable middleware. |
| IC2 | **Order: Recovery → Logging → Auth → Validation** | Recovery first to catch panics in all downstream interceptors. |
| IC3 | **Propagate metadata** | Extract and inject metadata for tracing, auth tokens, request IDs. |
| IC4 | **Use context for request-scoped data** | Pass user info, trace IDs through `context.Context`. |

```go
// Logging interceptor
func LoggingInterceptor(logger *slog.Logger) grpc.UnaryServerInterceptor {
    return func(
        ctx context.Context,
        req any,
        info *grpc.UnaryServerInfo,
        handler grpc.UnaryHandler,
    ) (any, error) {
        start := time.Now()
        resp, err := handler(ctx, req)
        duration := time.Since(start)

        code := status.Code(err)
        logger.LogAttrs(ctx, levelForCode(code),
            "grpc request",
            slog.String("method", info.FullMethod),
            slog.String("code", code.String()),
            slog.Duration("duration", duration),
        )

        return resp, err
    }
}
```

### 5. Streaming (Medium)

| # | Rule | Description |
|---|------|-------------|
| ST1 | **Use server streaming for large lists** | When response could be thousands of items. |
| ST2 | **Implement flow control** | Check `stream.Context().Done()` between sends. |
| ST3 | **Use client streaming for uploads** | Chunked file uploads, log ingestion. |
| ST4 | **Use bidi streaming for real-time** | Chat, live updates, collaborative editing. |

### 6. Testing (Medium)

| # | Rule | Description |
|---|------|-------------|
| GT1 | **Use bufconn for in-process testing** | No real network I/O, fast and reliable tests. |
| GT2 | **Test error codes** | Verify correct gRPC status codes for each error case. |
| GT3 | **Test with grpcurl** | Validate your API manually: `grpcurl -plaintext localhost:50051 list`. |

```go
func TestUserService(t *testing.T) {
    // In-process server using bufconn
    lis := bufconn.Listen(1024 * 1024)
    server := grpc.NewServer()
    pb.RegisterUserServiceServer(server, &userServer{svc: mockService})
    go server.Serve(lis)
    t.Cleanup(func() { server.Stop() })

    // Client
    conn, err := grpc.NewClient("passthrough:///bufnet",
        grpc.WithContextDialer(func(ctx context.Context, _ string) (net.Conn, error) {
            return lis.DialContext(ctx)
        }),
        grpc.WithTransportCredentials(insecure.NewCredentials()),
    )
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() { conn.Close() })

    client := pb.NewUserServiceClient(conn)

    t.Run("get existing user", func(t *testing.T) {
        resp, err := client.GetUser(context.Background(),
            &pb.GetUserRequest{Id: "123"})
        if err != nil {
            t.Fatal(err)
        }
        if resp.User.Name != "Alice" {
            t.Errorf("got name %q, want Alice", resp.User.Name)
        }
    })

    t.Run("get nonexistent user", func(t *testing.T) {
        _, err := client.GetUser(context.Background(),
            &pb.GetUserRequest{Id: "999"})
        if status.Code(err) != codes.NotFound {
            t.Errorf("got code %v, want NotFound", status.Code(err))
        }
    })
}
```

For protobuf style guide, see `references/protobuf-style.md`.
