#!/bin/bash
set -euo pipefail

# PostToolUse hook: auto-format and vet .go files after Edit/Write
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[[ "$file_path" == *.go ]] || exit 0
[[ -f "$file_path" ]] || exit 0

command -v gofumpt &>/dev/null && gofumpt -w "$file_path" 2>/dev/null || true
command -v goimports &>/dev/null && goimports -w "$file_path" 2>/dev/null || true

# Run go vet on the package containing the edited file
pkg_dir=$(dirname "$file_path")
command -v go &>/dev/null && go vet "./$pkg_dir/..." 2>&1 || true
