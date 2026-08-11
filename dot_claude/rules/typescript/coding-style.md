---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---
# TypeScript/JavaScript Coding Style

## Types

Never use `any`. Use a concrete type, a generic, or `unknown` plus narrowing:

```typescript
// WRONG
function render(column: any) { ... }

// CORRECT
function render<T>(column: Column<T>) { ... }

function parse(input: unknown) {
  if (typeof input !== 'string') throw new Error('expected string')
  return JSON.parse(input)
}
```

Run the project's lint and typecheck locally before opening a PR. An eslint or `tsc` failure in CI is a bug that should have been caught at edit time.

## Comparisons

Cast to number before comparing values that came from strings, JSON, env vars or CLI output — under lexical comparison `'2' < '10'` is `false`:

```typescript
// WRONG: lexical compare
if (batteryLevel < threshold) { ... }

// CORRECT
if (Number(batteryLevel) < Number(threshold)) { ... }
```

Same for sorting: `arr.sort()` is lexical. Use `arr.sort((a, b) => a - b)`.

## Immutability

Use spread operator for immutable updates:

```typescript
// WRONG: Mutation
function updateUser(user, name) {
  user.name = name  // MUTATION!
  return user
}

// CORRECT: Immutability
function updateUser(user, name) {
  return {
    ...user,
    name
  }
}
```

## Error Handling

Use async/await with try-catch:

```typescript
try {
  const result = await riskyOperation()
  return result
} catch (error) {
  console.error('Operation failed:', error)
  throw new Error('Detailed user-friendly message')
}
```

## Input Validation

Use Zod for schema-based validation:

```typescript
import { z } from 'zod'

const schema = z.object({
  email: z.string().email(),
  age: z.number().int().min(0).max(150)
})

const validated = schema.parse(input)
```

## Console.log

- No `console.log` statements in production code
- Use proper logging libraries instead
- See hooks for automatic detection
