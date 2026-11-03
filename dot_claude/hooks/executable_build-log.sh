#!/usr/bin/env bash
# Log build/test/compile commands that Claude Code agents run through Bash.
#
# Registered on PreToolUse, PostToolUse and PostToolUseFailure (matcher Bash).
# Pre stamps the start time and load average; Post/PostToolUseFailure append one
# line to ~/.local/state/build-telemetry/builds.jsonl. build-telemetry-report
# joins it with the machine samples from build-telemetry-sample.
#
# Never blocks or fails a tool call: every exit path is 0.
set -euo pipefail
trap 'exit 0' EXIT

state="$HOME/.local/state/build-telemetry"
pending="$state/pending"

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)
[[ -n "$cmd" ]] || exit 0

# A tool only counts in command position: line start, after ; & | (, or as the
# start of a bash -c script. Allows VAR=x prefixes, `time` and a path, so
# `cd x && CGO_ENABLED=0 go test` matches but `rg "go test"` and
# `echo "make sure"` do not. npx/bunx/pnpm exec count as runners, so the
# tool after them is what gets classified.
cmd_pos='(^|[;&|(]|bash -c '"['\"]"')[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(time[[:space:]]+)?((npx|bunx|pnpm (exec|dlx))[[:space:]]+)?([^[:space:];&|]*/)?'
cmd_end='([[:space:];&|)]|$)'

# Ordered: first match wins. Tests before the build tools that run them; generic
# package-manager runners last.
classify() {
  local c=$1
  local -a rules=(
    'go-test:go( -C [^[:space:]]+)? test'
    'go-build:go( -C [^[:space:]]+)? (build|install|vet|generate|run)'
    'go-lint:golangci-lint'
    'bun-test:bun( --cwd[= ][^[:space:]]+)? (run )?test'
    'js-test:(vitest|jest|playwright)'
    'tsc:tsc'
    'docker-build:docker (buildx )?(build|bake|compose)'
    'kind:kind (create|delete|load)'
    'cargo:cargo'
    'make:make'
    'hooks:(prek|pre-commit)'
    'bun:bunx?'
    'node-pm:(npm|pnpm|yarn|npx)'
  )
  local r
  for r in "${rules[@]}"; do
    if grep -Eq "${cmd_pos}${r#*:}${cmd_end}" <<<"$c"; then
      printf '%s' "${r%%:*}"
      return
    fi
  done
}

class=$(classify "$cmd")
[[ -n "$class" ]] || exit 0

event=$(jq -r '.hook_event_name' <<<"$input")
id=$(jq -r '.tool_use_id // empty' <<<"$input")
[[ "$id" =~ ^[A-Za-z0-9_-]+$ ]] || exit 0
now_ms=$((${EPOCHREALTIME/./} / 1000))
load1=$(sysctl -n vm.loadavg | awk '{print $2}')
mkdir -p "$pending"

if [[ "$event" == PreToolUse ]]; then
  printf '%s %s\n' "$now_ms" "$load1" >"$pending/$id"
  exit 0
fi

read -r start_ms load1_start 2>/dev/null <"$pending/$id" || true
rm -f "$pending/$id"
# ponytail: orphans come from Pre stamps whose call was blocked or cancelled.
find "$pending" -type f -mmin +1440 -delete 2>/dev/null || true

cwd=$(jq -r '.cwd // empty' <<<"$input")
worktree=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
if [[ -n "$common" ]]; then repo=$(basename "$(dirname "$common")"); else repo=$(basename "$cwd"); fi

jq -cn \
  --argjson in "$input" \
  --arg class "$class" \
  --arg worktree "$worktree" --arg repo "$repo" \
  --argjson now_ms "$now_ms" \
  --arg start_ms "${start_ms:-}" --arg load1_start "${load1_start:-}" \
  --argjson load1_end "$load1" \
  --argjson ncpu "$(sysctl -n hw.ncpu)" '
  ($in.duration_ms // (if $start_ms == "" then null else $now_ms - ($start_ms | tonumber) end)) as $dur
  | ($in.error // "") as $err
  | {
      ts_end: ($now_ms / 1000 | floor),
      duration_ms: $dur,
      duration_src: (if $in.duration_ms then "hook" elif $dur then "stamp" else null end),
      class: $class,
      status: (if $in.hook_event_name == "PostToolUse" then "ok"
               elif $in.is_interrupt then "interrupted" else "fail" end),
      exit: (if $in.hook_event_name == "PostToolUse" then 0
             else ($err | capture("^Exit code (?<n>[0-9]+)").n // null | if . then tonumber else null end) end),
      background: ($in.tool_input.run_in_background // false),
      repo: $repo, worktree: $worktree, cwd: $in.cwd,
      session_id: $in.session_id, tool_use_id: $in.tool_use_id,
      command: ($in.tool_input.command | .[0:500]),
      load1_start: (if $load1_start == "" then null else ($load1_start | tonumber) end),
      load1_end: $load1_end, ncpu: $ncpu
    }' >>"$state/builds.jsonl"
