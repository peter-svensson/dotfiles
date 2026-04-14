#!/usr/bin/env bash
set -euo pipefail

# Clean up worktrees whose branches have been integrated into the default branch.
# Runs at the end of each Claude Code session (Stop hook).

if ! command -v wt &>/dev/null || ! command -v jq &>/dev/null; then
  exit 0
fi

if ! git rev-parse --git-dir &>/dev/null 2>&1; then
  exit 0
fi

# Find integrated, non-current worktrees and remove them
wt list --format=json 2>/dev/null \
  | jq -r '.[] | select(.main_state == "integrated" and .is_current == false and .is_main == false) | .branch' \
  | while read -r branch; do
      wt remove "$branch" 2>/dev/null || true
    done
