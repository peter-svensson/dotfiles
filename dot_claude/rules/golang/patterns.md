---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go Patterns

> This file extends [common/patterns.md](../common/patterns.md) with Go specific content.

## Functional Options

```go
type Option func(*Server)

func WithPort(port int) Option {
    return func(s *Server) { s.port = port }
}

func NewServer(opts ...Option) *Server {
    s := &Server{port: 8080}
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

## Small Interfaces

Define interfaces where they are used, not where they are implemented.

## Dependency Injection

Use constructor functions to inject dependencies:

```go
func NewUserService(repo UserRepository, logger Logger) *UserService {
    return &UserService{repo: repo, logger: logger}
}
```

## Goose Migrations

All SQL migration files using [goose](https://github.com/pressly/goose) **must** include direction headers:

```sql
-- +goose Up
CREATE TABLE ...;

-- +goose Down
DROP TABLE ...;
```

- `-- +goose Up` is **required** — goose silently ignores the file without it
- `-- +goose Down` is optional but recommended for rollbacks
- Headers must be exact: `-- +goose Up` (two dashes, space, `+goose`, space, direction)

## Reference

See skill: `golang-patterns` for comprehensive Go patterns including concurrency, error handling, and package organization.
