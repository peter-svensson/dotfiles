---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go Testing


## Framework

Use the standard `go test` with **table-driven tests**.

## Race Detection

Always run with the `-race` flag:

```bash
go test -race ./...
```

## Coverage

```bash
go test -cover ./...
```

## Test Database Isolation

Never run tests against a shared dev or production database. Test helpers MUST use an isolated test database or in-memory alternative. Check for truncation/cleanup operations that could affect non-test data. If a project uses a shared database for development, confirm test config points to a separate test instance before running.

## Reference

See skill: `golang-testing` for detailed Go testing patterns and helpers.
