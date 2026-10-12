#!/usr/bin/env bash
set -uo pipefail

# PreToolUse(Bash) guard. Merged from gitbutler-commit-hook.py, the inline rm -rf
# guard, block-push-main.sh, git-staging-guard.sh and git-fresh.sh.
#
# Claude Code runs PreToolUse hooks sequentially, so five hooks meant five
# interpreter startups and five jq calls on every Bash tool call. This is one
# process, one jq call, and a fast path that spawns nothing at all for commands
# that mention neither git nor rm.
#
# Guards run before the gitbutler rewrite is emitted: a block must win over an
# allow decision.

input=$(cat)

# One jq call. The command is emitted last so the newlines in a multi-line
# command survive as "everything after the second line" -- @tsv would escape them
# and change how the matching below behaves.
parsed=$(printf '%s' "$input" | jq -r '(.tool_name // ""), (.cwd // ""), (.tool_input.command // "")' 2>/dev/null) || exit 0
TOOL=${parsed%%$'\n'*}
rest=${parsed#*$'\n'}
CWD=${rest%%$'\n'*}
CMD=${rest#*$'\n'}

[[ "$TOOL" == "Bash" && -n "$CMD" ]] || exit 0

# Fast path: nothing below can fire without one of these substrings.
case "$CMD" in
*git* | *rm* | *gh*) ;;
*) exit 0 ;;
esac

# Newlines flattened to ";" so a single bash regex keeps the line-start matching
# that the previous grep -E pipelines had.
FLAT=${CMD//$'\n'/;}

# --- 1. rm -r -f guard -------------------------------------------------------
if [[ "$FLAT" =~ (^|[\;\&\|][[:space:]]*)[Rr][Mm][[:space:]] ]] &&
  [[ "$FLAT" =~ (^|[[:space:]])-[a-zA-Z]*[rR]|--recursive ]] &&
  [[ "$FLAT" =~ (^|[[:space:]])-[a-zA-Z]*[fF]|--force ]]; then
  echo 'BLOCKED: Use trash instead of rm -rf' >&2
  exit 2
fi

# --- 2. protected-branch publish guard ---------------------------------------
if [[ "$FLAT" == *git*push* ]]; then
  # --force-with-lease / --force-if-includes are allowed: they refuse to
  # overwrite work that landed on the remote since the last fetch.
  SAFE=${FLAT//--force-with-lease/}
  SAFE=${SAFE//--force-if-includes/}
  if [[ "$SAFE" =~ (^|[\;\&\|][[:space:]]*)git[[:space:]]+push[^\;\&\|]*[[:space:]](--force|-f)([[:space:]]|$) ]]; then
    echo "BLOCKED: use --force-with-lease instead of --force/-f." >&2
    exit 2
  fi

  if [[ "$FLAT" =~ git[[:space:]]+push.*(main|master) ]]; then
    allowed_push=0
    ALLOWLIST="$HOME/.claude/hooks/push-main-allowed-repos"
    if [[ -f "$ALLOWLIST" ]]; then
      repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
      while IFS= read -r allowed; do
        [[ -z "$allowed" || "$allowed" == \#* ]] && continue
        if [[ "$allowed" == cmd-contains:* ]]; then
          pat="${allowed#cmd-contains:}"
          pat="${pat# }"
          if [[ -n "$pat" && "$CMD" == *"$pat"* ]]; then
            allowed_push=1
            break
          fi
          continue
        fi
        allowed="${allowed/#\~/$HOME}"
        if [[ -n "$repo_root" && "$repo_root" == "$allowed" ]]; then
          allowed_push=1
          break
        fi
      done <"$ALLOWLIST"
    fi
    if ((allowed_push == 0)); then
      echo "BLOCKED: Use feature branches, not direct publishing to a protected branch." >&2
      echo "Add the repo to ~/.claude/hooks/push-main-allowed-repos to allow." >&2
      exit 2
    fi
  fi
fi

# --- 3. git add staging guard ------------------------------------------------
# Blocks bulk adds, binaries, files >1MB and .gitignore drift on feature
# branches. Web media under public/ in the ambix web repo is exempt (no CDN,
# media ships from the repo).
if [[ "$FLAT" =~ (^|[[:space:]\;\&\|])git[[:space:]]+add([[:space:]]|$) ]]; then
  if [[ "${CLAUDE_ALLOW_BULK_ADD:-}" != "1" ]] &&
    [[ "$FLAT" =~ git[[:space:]]+add[[:space:]]+(-A|--all|\.([[:space:]]|$)) ]]; then
    echo "BLOCKED: bulk git add (-A / . / --all) pollutes PRs with unrelated files." >&2
    echo "List files explicitly. Override: prefix with CLAUDE_ALLOW_BULK_ADD=1 if intentional." >&2
    exit 2
  fi

  # Operands of the git add invocation only, stopping at the next &&/||/; -- a
  # line-oriented strip would tokenise unrelated lines of a multi-line command
  # (e.g. a heredoc commit message mentioning .gitignore) as staged filenames.
  FILES=$(echo "$CMD" |
    grep -oE 'git[[:space:]]+add[[:space:]][^&|;]*' |
    sed -E 's/^git[[:space:]]+add[[:space:]]+//' |
    tr -s '[:space:]' '\n' |
    grep -vE '^-' ||
    true)

  if [[ -n "$FILES" ]]; then
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
    cur_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    is_web_public_media() {
      [[ "$(basename "$repo_root")" == web || "$(basename "$repo_root")" == web.* ]] &&
        [[ "$1" == public/* || "$1" == */public/* ]] &&
        echo "$1" | grep -qiE '\.(png|jpe?g|webp|avif|svg|gif|mp4|webm)$'
    }

    # Committed codegen output (gqlgen's graph/generated/generated.go, graphql-
    # codegen's graphql/generated/operations.ts). It is regenerated from a
    # schema, is already tracked, and has to land in the same commit as that
    # schema or the build breaks -- so the size cap only produces a dead end.
    # Exempts the size check ONLY: the binary-extension check still applies, and
    # the file must already be tracked, so a new blob cannot arrive under a
    # generated-looking path.
    is_tracked_generated_code() {
      echo "$1" | grep -qE '(^|/)generated/' &&
        echo "$1" | grep -qiE '\.(go|ts)$' &&
        git ls-files --error-unmatch "$1" >/dev/null 2>&1
    }

    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      f="${f%\"}" f="${f#\"}"
      f="${f%\'}" f="${f#\'}"

      if echo "$f" | grep -qiE '\.(exe|bin|so|dylib|dll|a|o|dat|db|sqlite|sqlite3|class|jar|war|pyc|wasm|tar|gz|tgz|zip|7z|rar|iso|img|mp4|mov|avi|mkv|pdf)$' &&
        ! is_web_public_media "$f"; then
        echo "BLOCKED: refusing to stage binary-like file: $f" >&2
        echo "If intentional, add via plain git outside this session or add ext to repo .gitattributes." >&2
        exit 2
      fi

      full="$f"
      [[ -n "$repo_root" && "$f" != /* ]] && full="$repo_root/$f"

      if [[ -f "$full" ]]; then
        size=$(stat -f%z "$full" 2>/dev/null || stat -c%s "$full" 2>/dev/null || echo 0)
        limit=1048576
        is_web_public_media "$f" && limit=3145728
        if [[ "$size" -gt "$limit" ]] && ! is_tracked_generated_code "$f"; then
          echo "BLOCKED: file >$((limit / 1048576))MB ($((size / 1024))KB): $f" >&2
          echo "Large files rarely belong in source PRs. Use git-lfs or add to .gitignore." >&2
          exit 2
        fi
      fi

      # A dedicated *gitignore* branch IS the rule's intent satisfied -- main is
      # protected, so without that escape hatch genuine .gitignore fixes have no
      # path to land at all.
      if [[ "$(basename "$f")" == ".gitignore" ]]; then
        case "$cur_branch" in
        main | master | gitbutler/workspace | *gitignore*) ;;
        *)
          echo "BLOCKED: .gitignore change on feature branch ($cur_branch)." >&2
          echo ".gitignore drift usually leaks into unrelated PRs." >&2
          echo "Use a dedicated branch whose name contains gitignore, so the change lands as its own PR." >&2
          exit 2
          ;;
        esac
      fi
    done <<<"$FILES"
  fi
fi

# --- 4. ref freshness --------------------------------------------------------
# Refresh refs before commands whose output gets used to reason about
# branch/PR/merge state, so conclusions never come from stale local refs.
# Throttled per repo, and detached so the fetch never delays the tool call.
if [[ "$FLAT" =~ (^|[[:space:]\;\&\|])(gh[[:space:]]+(pr|run)[[:space:]]|git[[:space:]]+(log|status|branch|rev-list|merge-base|diff)) ]]; then
  (
    # ponytail: repo taken from the session cwd; a command that cds elsewhere first is skipped.
    if [[ -n "$CWD" && -d "$CWD" ]]; then cd "$CWD" || exit 0; fi
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
    stamp="$git_dir/.claude-last-fetch"
    now=$(date +%s)
    last=0
    [[ -f "$stamp" ]] && last=$(cat "$stamp" 2>/dev/null || echo 0)
    ((now - last < 300)) && exit 0
    echo "$now" >"$stamp"
    timeout 20 git fetch --all --prune --quiet 2>/dev/null || true
  ) >/dev/null 2>&1 &
  disown 2>/dev/null || true
fi

# --- 5. gitbutler rewrite ----------------------------------------------------
# On gitbutler/workspace, git commit/status must go through the but CLI. The
# branch lookup only runs for commands that could be rewritten; the old python
# hook shelled out to git on every single Bash call.
case "$CMD" in
"git commit"* | "git status"* | "git add"*)
  if [[ "$(git branch --show-current 2>/dev/null)" == "gitbutler/workspace" ]]; then
    new=""
    case "$CMD" in
    "git commit"*) new=${CMD/git commit/but commit} ;;
    "git status"*) new=${CMD/git status/but status} ;;
    "git add"*)
      if [[ "$CMD" == *"&&"* && "$CMD" == *"git commit"* ]]; then
        new=${CMD//git commit/but commit}
      fi
      ;;
    esac
    if [[ -n "$new" ]]; then
      printf '%s' "$input" |
        jq -c --arg cmd "$new" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",permissionDecisionReason:"On gitbutler/workspace: using but CLI",updatedInput:(.tool_input + {command:$cmd})}}'
    fi
  fi
  ;;
esac

exit 0
