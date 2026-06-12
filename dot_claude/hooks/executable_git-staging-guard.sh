#!/usr/bin/env bash
set -euo pipefail

# PreToolUse guard against PR-polluting git staging operations.
#
# Blocks/warns:
#   1. Bulk add: `git add -A`, `git add .`, `git add --all`
#   2. Staging binaries (extensions: exe, bin, so, dylib, dll, a, o, dat, db, sqlite, sqlite3)
#   3. Staging files larger than 1MB
#   4. Staging .gitignore changes on non-main/master branches
#
# Exemption: web assets (png/jpg/jpeg/webp/avif/svg/gif + mp4/webm video) under
# public/ in the ambix `web` repo (incl. its `web.*` worktrees) pass the binary
# and size checks up to 3MB — the site has no CDN, media ships from the repo.
#
# Override: set CLAUDE_ALLOW_BULK_ADD=1 to skip bulk-add block for one invocation.

CMD=$(jq -r '.tool_input.command')

# Only inspect git add invocations
if ! echo "$CMD" | grep -qE '(^|[[:space:]]|;|&&|\|\|)git[[:space:]]+add([[:space:]]|$)'; then
  exit 0
fi

# 1. Bulk add detection
if [[ "${CLAUDE_ALLOW_BULK_ADD:-}" != "1" ]]; then
  if echo "$CMD" | grep -qE 'git[[:space:]]+add[[:space:]]+(-A|--all|\.([[:space:]]|$))'; then
    echo "BLOCKED: bulk git add (-A / . / --all) pollutes PRs with unrelated files." >&2
    echo "List files explicitly. Override: prefix with CLAUDE_ALLOW_BULK_ADD=1 if intentional." >&2
    exit 2
  fi
fi

# Extract candidate files: strip "git add" + flags
FILES=$(echo "$CMD" \
  | sed -E 's/.*git[[:space:]]+add[[:space:]]+//' \
  | sed -E 's/[[:space:]]*(&&|\|\||;).*//' \
  | tr -s '[:space:]' '\n' \
  | grep -vE '^-' \
  || true)

if [[ -z "$FILES" ]]; then
  exit 0
fi

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
cur_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# web/public media exemption (images + mp4/webm): the ambix web repo serves
# media straight from the repo (no CDN). Checked per-file below.
is_web_public_media() {
  [[ "$(basename "$repo_root")" == web || "$(basename "$repo_root")" == web.* ]] \
    && [[ "$1" == public/* || "$1" == */public/* ]] \
    && echo "$1" | grep -qiE '\.(png|jpe?g|webp|avif|svg|gif|mp4|webm)$'
}

# 2 + 3 + 4: per-file checks
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # Strip surrounding quotes
  f="${f%\"}"; f="${f#\"}"
  f="${f%\'}"; f="${f#\'}"

  # 2. Binary extension (web/public media exempt)
  if echo "$f" | grep -qiE '\.(exe|bin|so|dylib|dll|a|o|dat|db|sqlite|sqlite3|class|jar|war|pyc|wasm|tar|gz|tgz|zip|7z|rar|iso|img|mp4|mov|avi|mkv|pdf)$' \
    && ! is_web_public_media "$f"; then
    echo "BLOCKED: refusing to stage binary-like file: $f" >&2
    echo "If intentional, add via plain git outside this session or add ext to repo .gitattributes." >&2
    exit 2
  fi

  # Path resolution
  full="$f"
  if [[ -n "$repo_root" && "$f" != /* ]]; then
    full="$repo_root/$f"
  fi

  # 3. Large file (>1MB; 3MB for web/public media — no CDN, media ships from repo)
  if [[ -f "$full" ]]; then
    size=$(stat -f%z "$full" 2>/dev/null || stat -c%s "$full" 2>/dev/null || echo 0)
    limit=1048576
    if is_web_public_media "$f"; then
      limit=3145728
    fi
    if [[ "$size" -gt "$limit" ]]; then
      echo "BLOCKED: file >$((limit/1048576))MB ($((size/1024))KB): $f" >&2
      echo "Large files rarely belong in source PRs. Use git-lfs or add to .gitignore." >&2
      exit 2
    fi
  fi

  # 4. .gitignore on feature branch
  if [[ "$(basename "$f")" == ".gitignore" ]]; then
    case "$cur_branch" in
      main|master|gitbutler/workspace) ;;
      *)
        echo "BLOCKED: .gitignore change on feature branch ($cur_branch)." >&2
        echo ".gitignore drift usually leaks into unrelated PRs. Land separately on main first." >&2
        exit 2
        ;;
    esac
  fi
done <<< "$FILES"

exit 0
