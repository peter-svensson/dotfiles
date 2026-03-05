---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with Go specific content.

## Formatting

- **gofumpt** and **goimports** are mandatory — auto-applied via PostToolUse hook on every `.go` edit

## Pre-Completion Gate (MANDATORY)

Do NOT declare any Go task complete until ALL of these pass with zero errors:
1. `go build ./...`
2. `go vet ./...`
3. `golangci-lint run ./...`
4. `go test -race ./...` (on affected packages at minimum)

If any check fails, fix the issue and re-run. Never skip this step, never report completion with outstanding warnings.

## Design Principles

- Accept interfaces, return structs
- Keep interfaces small (1-3 methods)

## Error Handling

Always wrap errors with context:

```go
if err != nil {
    return fmt.Errorf("failed to create user: %w", err)
}
```

## GraphQL (gqlgen)

- We use [gqlgen](https://github.com/99designs/gqlgen) for GraphQL in all Go services
- After changing a `.graphqls` schema file, run:
  1. `go generate ./...`
  2. `goimports -w .`
  3. `gofumpt -w .`

## Goose migrations

Always name goose migrations with a numeric prefix with current date and time following the YYYYMMDDHHmmss format

## Reference

See skill: `golang-patterns` for comprehensive Go idioms and patterns.
