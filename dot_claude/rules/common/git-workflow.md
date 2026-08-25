# Git Workflow

## Commit Message Format

```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

## Pull Request Workflow

When creating PRs:
1. Analyze full commit history (not just latest commit)
2. Use `git diff [base-branch]...HEAD` to see all changes
3. Draft comprehensive PR summary
4. Include test plan with TODOs
5. Push with `-u` flag if new branch

## Feature Implementation Workflow

1. **Plan First** (for non-trivial features)
   - Use **planner** agent for complex features
   - Identify dependencies and risks
   - Break down into phases

2. **Implement**
   - Bias toward action for straightforward work
   - Use **tdd-guide** agent when the user requests TDD or the feature has complex edge cases
   - Follow conventional commits format

## GitButler

On the `gitbutler/workspace` branch, plain git staging and publishing commands are
wrong: use the `but` CLI. Invoke the **gitbutler** skill for the workflow and full
command reference.
