#!/usr/bin/env bash
set -euo pipefail

# PreToolUse(Bash) hook: refresh refs before any command whose output gets used to
# reason about branch/PR/merge state, so conclusions never come from stale local refs.
# Throttled per repo; never blocks (always exits 0).
input=$(cat)
CMD=$(echo "$input" | jq -r '.tool_input.command // empty')
CWD=$(echo "$input" | jq -r '.cwd // empty')

echo "$CMD" | grep -qE '(^|[;&|[:space:]])(gh[[:space:]]+(pr|run)[[:space:]]|git[[:space:]]+(log|status|branch|rev-list|merge-base|diff))' || exit 0

# ponytail: repo taken from the session cwd; a command that cds elsewhere first is skipped.
[[ -n "$CWD" && -d "$CWD" ]] && cd "$CWD"
git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0

stamp="$git_dir/.claude-last-fetch"
now=$(date +%s)
last=0
[[ -f "$stamp" ]] && last=$(cat "$stamp" 2>/dev/null || echo 0)
((now - last < 300)) && exit 0

echo "$now" >"$stamp"
timeout 20 git fetch --all --prune --quiet 2>/dev/null || true
exit 0
