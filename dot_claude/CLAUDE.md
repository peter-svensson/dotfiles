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

## Git & PR Hygiene

- Never run `git add -A`, `git add .`, or `git add --all`. The git-staging-guard hook blocks them. Stage explicit file lists only.
- Before staging: run `git status` and `git diff --stat`, then confirm the file list with the user.
- Never stage binaries (exe, bin, so, dylib, archives, media, PDFs, sqlite). The hook blocks them.
- Never stage one-off migration tools, backfill scripts, or debug instrumentation in a feature PR. Land separately.
- Never modify `.gitignore` on a feature branch. Land separately on main first.
- Never stage files unrelated to the accepted findings/task scope. If you discover other issues, surface them and ask before touching.
- After staging, verify with `git diff --cached --stat` that staged files match the intended list. If anything unexpected appears, `git restore --staged <file>` and report.
- On `gitbutler/workspace`: use `but rub <cliId> <branch>` for hunk assignment, verify with `but status --json`, then `but commit --only`. Never raw `git add`.

## Source of Truth

- Read the actual file, log, or document before summarizing status. Never answer from memory about current state of roadmaps, docs, schemas, or feature completion.
- For production incidents: read recent logs and inspect current code BEFORE proposing a hypothesis. Do not dismiss errors as "benign", "expected behavior", "bot traffic", or "spot reclaim" without evidence quoted from logs or code.
- If the user corrects a factual claim, restate the corrected fact in one sentence before continuing. Update auto-memory if the corrected fact is durable.
- When a memory record names a specific file/function/flag, verify it still exists (grep / read) before acting on it. Stale memory is common.

## Debug Protocol

For non-trivial production issues, do not propose a fix on first hypothesis. Instead:

1. Gather evidence in parallel: recent logs, recent deploys/commits (last 7 days), current config/deployment state, schema/client-version drift.
2. Output 3 ranked hypotheses with confidence + supporting evidence (file:line, log timestamp, commit SHA).
3. Propose the cheapest verification step for the top hypothesis.
4. Only after the user accepts a hypothesis: write the fix.

Spawn parallel Task subagents for the evidence gathering when the issue spans multiple services or surfaces.

## Design Confirmation

Before writing code for any non-trivial change (new feature, refactor, architecture-touching fix), restate in 3-5 bullets:

1. Data flow involved
2. Services/files that will change
3. User-facing behavior expected
4. Explicit assumptions (event level, clock semantics, caching boundary, deduplication strategy, persistence layer)

Wait for user confirmation before coding. A 30-second confirmation prevents a 30-minute revert.

Trigger words that require this step: "implement", "add support for", "wire up", "integrate", "migrate", "refactor", "extract", any work touching events, schedulers, caches, or cross-service boundaries.
