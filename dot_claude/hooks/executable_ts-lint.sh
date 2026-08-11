#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: lint + autofix TS/JS files after Edit/Write, so eslint
# failures surface at edit time instead of in CI.
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

case "$file_path" in
*.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs) ;;
*) exit 0 ;;
esac
[[ -f "$file_path" ]] || exit 0

# Nearest package.json is the project root; bail out if the file is not in a JS project
dir=$(cd "$(dirname "$file_path")" && pwd)
root=""
while [[ "$dir" != "/" ]]; do
  if [[ -f "$dir/package.json" ]]; then
    root="$dir"
    break
  fi
  dir=$(dirname "$dir")
done
[[ -n "$root" ]] || exit 0
[[ -d "$root/node_modules/eslint" ]] || exit 0

cd "$root"
# ponytail: single-file eslint only; no tsc --noEmit (whole-program, too slow per edit).
# Add typecheck here if type errors start reaching CI.
if ! out=$(timeout 60 npx --no-install eslint --fix "$file_path" 2>&1); then
  {
    echo "eslint failed on $file_path — fix before continuing:"
    echo "$out"
  } >&2
  exit 2
fi
