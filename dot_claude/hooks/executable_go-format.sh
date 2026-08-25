#!/bin/bash
set -euo pipefail

# PostToolUse hook: auto-format and vet .go files after Edit/Write
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[[ "$file_path" == *.go ]] || exit 0
[[ -f "$file_path" ]] || exit 0

command -v gofumpt &>/dev/null && gofumpt -w "$file_path" 2>/dev/null || true
command -v goimports &>/dev/null && goimports -w "$file_path" 2>/dev/null || true

# ponytail: format only. `go vet ./$pkg_dir/...` used to run here, but file_path is
# absolute so the pattern expanded to ".//Users/..." and vet never actually ran.
# Vetting for real costs seconds per edit and re-runs on every keystroke-sized
# change; CI already vets. Add it back here if vet failures start reaching CI.
