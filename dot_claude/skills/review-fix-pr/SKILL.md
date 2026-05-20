---
name: review-fix-pr
description: Branch review → triage → scoped fixes → PR. Enforces explicit file scope and prevents PR pollution (binaries, unrelated changes, .gitignore drift). Use when user says "review this branch", "review and fix", "code review", "/review-fix-pr", or asks to triage a branch end-to-end.
---

# Review → Fix → PR

User's most frequent workflow. Past friction: wrong branch identified, binaries staged, migration tools committed to feature PRs, .gitignore drift, GitButler hunk confusion. This skill enforces strict scoping at every step.

## When to Activate

- "review this branch"
- "review and fix"
- "code review then commit"
- "/review-fix-pr"
- Any branch-scoped review followed by intended changes

## Phase 1 — Lock Scope (BEFORE reading code)

Run these in parallel:

```sh
git rev-parse --abbrev-ref HEAD
git log main..HEAD --oneline           # adjust base if not main
git diff main...HEAD --stat
```

Then output to user:
1. Current branch name
2. Commits on this branch (count + subjects)
3. Files changed (count + list)
4. Base branch assumed

**WAIT** for user to confirm scope before proceeding. If user names a different base branch (master, develop, gitbutler/workspace target), redo with that.

## Phase 2 — Review

Read every changed file. Evaluate in order: **architecture → correctness → tests → security → performance**.

Output a numbered list. For each finding:

```
N. [SEV] file.ext:LINE — short title
   Issue: <concrete description>
   Options: A) ..., B) ...
   Recommended: A — <reason>
```

Severity tags: `CRITICAL` / `HIGH` / `MED` / `LOW` / `NIT`.

**WAIT** for user triage. Do not stage anything yet. User picks which findings to fix.

## Phase 3 — Fix (scoped)

For each accepted finding:
1. Identify exact files needed for that fix
2. Edit only those files
3. Re-read change against the finding — confirm it addresses the issue

After all fixes:

```sh
git status
git diff --stat
```

Show user the intended file list. **WAIT** for confirmation.

## Phase 4 — Stage (strict)

NEVER use `git add -A` / `git add .` / `git add --all`. The git-staging-guard hook blocks them.

Stage explicitly:

```sh
git add path/to/file1 path/to/file2
```

Refuse to stage:
- Binaries (`.exe`, `.bin`, `.so`, `.dylib`, archives, media, PDFs)
- One-off migration tools / scripts not part of the issue
- `.gitignore` changes on feature branches — land separately on main
- Files unrelated to the accepted findings

If user insists on something the hook blocks, ask them to run `CLAUDE_ALLOW_BULK_ADD=1` themselves outside the session.

## Phase 5 — Verify Pre-Commit

```sh
git diff --cached --stat
```

Confirm staged files == intended file list from Phase 3. If diff includes anything unexpected, `git restore --staged <file>` and report.

Run pre-commit hooks:

```sh
prek run --all-files   # or pre-commit run --all-files if prek unavailable
```

Fix any reported issues by editing source, NOT by skipping hooks.

## Phase 6 — Commit & PR

Conventional commits format: `<type>: <description>`. Squash-merge target — single descriptive commit per logical change.

```sh
git commit -m "<type>: <description>"
git push -u origin <branch>          # use `but push <branch>` on gitbutler/workspace
gh pr create --title "..." --body "$(cat <<'EOF'
## Summary
- bullet 1
- bullet 2

## Test plan
- [ ] item
EOF
)"
```

PR description rules (from CLAUDE.md):
- Describe what the code does NOW, not discarded approaches
- Avoid hype: critical, crucial, essential, significant, comprehensive, robust, elegant
- Include Linear issue ref if applicable (ESTER-xxx)

## GitButler Variant

If `git rev-parse --abbrev-ref HEAD` == `gitbutler/workspace`:
- Replace `git push` → `but push <branch>`
- Replace `gh pr create` → `but pr new -m "title\n\nbody" <branch>`
- Use `but rub <cliId> <branch>` for hunk assignment, never raw `git add`
- Verify with `but status --json` that hunks land on intended branch before `but commit --only`

## Anti-Patterns (auto-refuse)

- `git add -A` / `git add .` — bulk add
- Staging files outside the accepted-finding set
- "While I'm in here, also fix X" — open separate PR
- Including a migration/backfill tool because it was useful during debugging
- Bumping unrelated dependencies
- Reformatting files not touched by findings

## Checklist (read before claiming done)

- [ ] Phase 1 scope confirmed by user
- [ ] Phase 2 findings triaged by user
- [ ] Phase 4 staged file list == Phase 3 intended file list
- [ ] No binaries staged
- [ ] No `.gitignore` on feature branch
- [ ] Pre-commit hooks pass
- [ ] PR description follows CLAUDE.md rules
- [ ] Linear ref included if applicable
