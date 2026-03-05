- always unzip files to a temporary directory
- Always add all files to git before running pre-commit since it stashes all unstaged files when running
- I use GNU versions of rm and cp which ask for confirmation on replace and remove.
- Always explicitly specify the context when running `kubectl` commands using `--context <context>`. Check the project's `.buildtools.yaml` or `.envrc` for the expected k8s context. Never rely on the current default context — it may point to a different cluster (e.g., production instead of local). For local development, the context typically follows the pattern: `kind-<project-name>`

## Workflow Orchestration

### Plan Mode
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity
- Pour energy into the plan so implementation can be done in one shot

### Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### Self-Improvement Loop
- After ANY correction from the user: update auto-memory or the relevant CLAUDE.md with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these rules until mistake rate drops
- Keep migration tracking, plan, and memory files up to date at the end of every session that completes meaningful work
- Before starting phased or migration work: read the memory/plan file, then verify it against actual codebase state (check which files exist, which tests pass, git log). Update the file if outdated. Never trust stale docs — they cost entire sessions of wasted exploration

### Verification Before Done
- Never mark a task complete without proving it works
- Before creating PRs: run the full lint and test suite if available
- Re-read your changes for unnecessary complexity, redundant code, and unclear naming
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"

### Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: rethink and implement the elegant solution
- Skip this for simple, obvious fixes — don't over-engineer

### Autonomous Bug Fixing
- When given a bug report: just fix it — don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Go fix failing CI tests without being told how

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Minimal code impact.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs. If you identify something that seems like it should change but wasn't requested, mention it and wait for approval — do not modify it.
- **Replace, don't deprecate**: When new replaces old, remove the old entirely. No backward-compat shims, dual config formats, or migration paths. Proactively flag dead code.
- **No phantom features**: Don't document or validate features that aren't implemented.
- **Justify new dependencies**: Each dependency is attack surface and maintenance burden. Justify before adding.
- **No premature abstraction**: Don't create utilities until the same code is written three times.
- **Bias toward action**: Decide and move for anything easily reversed; state the assumption. Ask before committing to interfaces, data models, architecture, or destructive ops. When assigned a task, proceed directly to implementation — do not spend the session exploring and asking clarifying questions unless explicitly asked to plan first.
- **Finish the job**: Handle edge cases you can see. Clean up what you touched. Flag broken adjacent things. But don't invent new scope — thoroughness is not gold-plating.
- **Verify at every level**: Prefer structure-aware tools (ast-grep, LSPs, compilers) over text pattern matching when searching for code structure. Review your own output critically.
- **Look up versions**: When adding dependencies, CI actions, or tool versions, always look up the current stable version — never assume from memory.

## Code Discipline

### Hard Limits
- ≤100 lines per function, cyclomatic complexity ≤8
- ≤5 positional parameters — use options objects/structs beyond that

### Zero Warnings Policy
Fix every warning from every tool — linters, type checkers, compilers, tests. If a warning truly can't be fixed, add an inline ignore with a justification comment. Never leave warnings unaddressed.

### Comments
No commented-out code — delete it. If you need a comment to explain WHAT the code does, refactor the code instead. Comments explain WHY, not WHAT.

### Error Handling
- Fail fast with clear, actionable messages
- Never swallow exceptions silently
- Include context: what operation failed, what input caused it, suggested fix

### Testing Philosophy
- **Test behavior, not implementation** — if a refactor breaks tests but not code, the tests were wrong
- **Test edges and errors**, not just the happy path — bugs live in boundaries and error paths
- **Mock boundaries, not logic** — only mock slow, non-deterministic, or external things
- **Verify tests catch failures** — break the code, confirm the test fails, then fix

### Code Review Order
Evaluate: architecture → code quality → tests → performance. For each issue: describe concretely with file:line references, present options with tradeoffs, recommend one.

### PR Descriptions
Describe what the code does now — not discarded approaches, prior iterations, or alternatives. Use plain, factual language. Avoid hype words: critical, crucial, essential, significant, comprehensive, robust, elegant.

## CLI Tools

Prefer these over slower defaults:

| Tool | Replaces | Usage |
|------|----------|-------|
| `rg` (ripgrep) | grep | `rg "pattern"` — fast regex search |
| `fd` | find | `fd "*.py"` — fast file finder |
| `ast-grep` | — | `ast-grep --pattern '$FUNC($$$)' --lang py` — AST-based code search |
| `shellcheck` | — | `shellcheck script.sh` — shell script linter |
| `shfmt` | — | `shfmt -i 2 -w script.sh` — shell formatter |
| `actionlint` | — | `actionlint .github/workflows/` — GitHub Actions linter |
| `zizmor` | — | `zizmor .github/workflows/` — Actions security audit |
| `prek` | pre-commit | `prek run --all-files` — fast pre-commit runner |
| `trash` | rm | `trash file` — moves to macOS Trash (recoverable). **Never use `rm -rf`** |

Prefer `ast-grep` over ripgrep when searching for code structure (function calls, class definitions, imports). Use ripgrep for literal strings and log messages.

## Shell & CI

### Shell Scripts
- All bash scripts must start with `set -euo pipefail`
- Lint with `shellcheck` and format with `shfmt` before committing

### GitHub Actions
- Pin actions to SHA hashes with version comments: `actions/checkout@<full-sha>  # vX.Y.Z`
- Use `persist-credentials: false` on checkout actions
- Scan workflows with `actionlint` and `zizmor` before committing

### Worktrees (Plain Git Repos)

When NOT on a `gitbutler/workspace` branch, use git worktrees for parallel work:
- Parallel subagents require worktrees — each subagent MUST work in its own worktree, not the main repo
- For feature work that benefits from isolation: `git worktree add ../<repo>-<branch> -b <branch>`
- Clean up after merging: `git worktree remove ../<repo>-<branch>`
- List active worktrees: `git worktree list`

### prek (Git Hooks)

Install prek in every repo that has a `.pre-commit-config.yaml`:
- `prek install` — installs git hooks
- `prek run` — run hooks before committing
- Configure auto-updates: `prek auto-update --cooldown-days 7`
