- Always unzip files to a temporary directory
- Always add all files to git before running pre-commit (it stashes unstaged files)
- I use GNU versions of rm and cp which ask for confirmation on replace and remove
- My shell is fish. All shell commands must use fish syntax (no bash-isms). Use fish idioms: `for x in (command)`, `set -x FOO bar`, etc.
- Files managed by chezmoi must not be edited directly. Edit source files in the chezmoi source directory (`chezmoi source-path`)
- Always specify `--context <context>` for kubectl. Check `.buildtools.yaml` or `.envrc` for the expected context. Never rely on the default.
- Never use quote characters in # comments in Bash tool commands (triggers desync quote tracking warning)

## Workflow Orchestration

### Plan Mode
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately
- Write detailed specs upfront so implementation can be done in one shot

### Self-Improvement Loop
- After ANY correction: update auto-memory or CLAUDE.md with the pattern
- Before starting phased work: read memory/plan files, verify against actual codebase state, update if outdated

### Verification Before Done
- Never mark a task complete without proving it works
- Before creating PRs: run the full lint and test suite
- Re-read changes for unnecessary complexity and unclear naming
- Diff behavior between main and your changes when relevant

### Autonomous Bug Fixing
- When given a bug report: just fix it. Point at logs, errors, failing tests, then resolve them.

## Core Principles

- **Minimal Impact**: Only touch what's necessary. If something seems like it should change but wasn't requested, mention it and wait for approval.
- **Replace, don't deprecate**: Remove the old entirely. No backward-compat shims or migration paths.
- **No phantom features**: Don't document or validate features that aren't implemented.
- **Justify new dependencies**: Each is attack surface and maintenance burden.
- **Bias toward action**: Decide and move for anything easily reversed; state the assumption. Ask before committing to interfaces, data models, architecture, or destructive ops.
- **Finish the job**: Handle edge cases you can see. Clean up what you touched. Flag broken adjacent things. Don't invent new scope.
- **Verify at every level**: Prefer ast-grep, LSPs, compilers over text pattern matching for code structure.
- **Look up versions**: When adding dependencies, CI actions, or tool versions, always look up the current stable version.

## Code Discipline

### Hard Limits
- ≤100 lines per function, cyclomatic complexity ≤8
- ≤5 positional parameters — use options objects/structs beyond that

### Zero Warnings Policy
Fix every warning from every tool. If unfixable, add an inline ignore with justification.

### Code Review Order
Evaluate: architecture → code quality → tests → performance. For each issue: describe concretely with file:line, present options with tradeoffs, recommend one.

### PR Descriptions
Describe what the code does now — not discarded approaches. Avoid hype words: critical, crucial, essential, significant, comprehensive, robust, elegant.

## CLI Tools

| Tool | Replaces | Usage |
|------|----------|-------|
| `rg` | grep | `rg "pattern"` |
| `fd` | find | `fd "*.py"` |
| `ast-grep` | — | `ast-grep --pattern '$FUNC($$$)' --lang py` |
| `shellcheck` | — | `shellcheck script.sh` |
| `shfmt` | — | `shfmt -i 2 -w script.sh` |
| `actionlint` | — | `actionlint .github/workflows/` |
| `zizmor` | — | `zizmor .github/workflows/` |
| `prek` | pre-commit | `prek run --all-files` |
| `trash` | rm | `trash file` — **never use `rm -rf`** |

Prefer `ast-grep` over ripgrep for code structure. Use ripgrep for literal strings.

## Shell & CI

### Shell Scripts
- All bash scripts: `set -euo pipefail`
- Lint with `shellcheck`, format with `shfmt`

### GitHub Actions
- Pin actions to SHA hashes: `actions/checkout@<full-sha>  # vX.Y.Z`
- `persist-credentials: false` on checkout
- Scan with `actionlint` and `zizmor`

### GitHub API
- NEVER use `mcp__github__create_or_update_file` — it creates unsigned commits. Always commit locally.

### Worktrees (Plain Git Repos)

When NOT on `gitbutler/workspace` and the task involves code changes:
- Create a worktree first: `wt switch -c <branch-name>`
- Use `wt` commands, not raw `git worktree`
- One worktree per repo per task
- Parallel subagents require separate worktrees
- Clean up after PR: `wt remove <worktree>`

### prek (Git Hooks)

For repos with `.pre-commit-config.yaml`:
- `prek install` / `prek run` / `prek auto-update --cooldown-days 7`
