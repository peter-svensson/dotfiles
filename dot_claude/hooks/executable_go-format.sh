#!/bin/bash
set -euo pipefail

# PostToolUse hook: auto-format .go files after Edit/Write
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[[ "$file_path" == *.go ]] || exit 0
[[ -f "$file_path" ]] || exit 0

command -v gofumpt &>/dev/null && gofumpt -w "$file_path" 2>/dev/null || true
command -v goimports &>/dev/null && goimports -w "$file_path" 2>/dev/null || true
