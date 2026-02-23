---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with Go specific content.

## Formatting

- **gofumpt** and **goimports** are mandatory — no style debates

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

## Graphql schemas

Always run go generate ./... when changing a graphql schema

## Goose migrations

Always name goose migrations with a numeric prefix with current date and time following the YYYYMMDDHHmmss format

## Reference

See skill: `golang-patterns` for comprehensive Go idioms and patterns.
