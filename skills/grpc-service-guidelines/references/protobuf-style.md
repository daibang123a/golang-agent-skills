# Protobuf Style Guide for Go Services

## File Organization

```
proto/
├── user/
│   └── v1/
│       ├── user.proto           # Service definition
│       └── user_types.proto     # Shared types (optional)
├── order/
│   └── v1/
│       └── order.proto
└── buf.yaml                     # Buf configuration
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Package | `lowercase.v1` | `userservice.v1` |
| Service | `PascalCase` + `Service` | `UserService` |
| RPC | `PascalCase` verb | `GetUser`, `ListUsers`, `CreateUser` |
| Message | `PascalCase` | `GetUserRequest`, `GetUserResponse` |
| Field | `snake_case` | `user_id`, `created_at` |
| Enum | `SCREAMING_SNAKE` | `USER_ROLE_ADMIN` |
| Enum prefix | Type name prefix | `USER_ROLE_UNSPECIFIED = 0` |

## Standard Method Patterns (AIP-inspired)

```protobuf
service BookService {
  // Standard CRUD
  rpc GetBook(GetBookRequest) returns (Book);
  rpc ListBooks(ListBooksRequest) returns (ListBooksResponse);
  rpc CreateBook(CreateBookRequest) returns (Book);
  rpc UpdateBook(UpdateBookRequest) returns (Book);
  rpc DeleteBook(DeleteBookRequest) returns (google.protobuf.Empty);

  // Custom methods
  rpc ArchiveBook(ArchiveBookRequest) returns (Book);
}
```

## Pagination

```protobuf
message ListBooksRequest {
  int32 page_size = 1;     // Max items per page (server caps this)
  string page_token = 2;   // Opaque cursor from previous response
  string filter = 3;       // Optional filter expression
  string order_by = 4;     // e.g., "created_at desc"
}

message ListBooksResponse {
  repeated Book books = 1;
  string next_page_token = 2;  // Empty if no more pages
  int32 total_size = 3;        // Optional: total count
}
```

## Buf Configuration

```yaml
# buf.yaml
version: v2
modules:
  - path: proto
lint:
  use:
    - DEFAULT
breaking:
  use:
    - FILE
```

## Code Generation

```bash
# Install buf
go install github.com/bufbuild/buf/cmd/buf@latest

# Generate Go code
buf generate

# Lint protobuf files
buf lint

# Check backward compatibility
buf breaking --against '.git#branch=main'
```

## buf.gen.yaml

```yaml
version: v2
plugins:
  - remote: buf.build/protocolbuffers/go
    out: gen
    opt: paths=source_relative
  - remote: buf.build/grpc/go
    out: gen
    opt: paths=source_relative
```
