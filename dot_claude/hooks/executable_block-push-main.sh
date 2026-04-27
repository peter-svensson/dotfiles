#!/usr/bin/env bash
set -euo pipefail

# Block git push to main/master unless allowed by ~/.claude/hooks/push-main-allowed-repos.
# Entry formats:
#   <absolute-path>          matched against `git rev-parse --show-toplevel` of the local CWD
#   cmd-contains: <string>   allowed if the bash command contains the given substring
#                            (use this for remote-shell pushes, e.g. "ssh user@host")

CMD=$(jq -r '.tool_input.command')

# Only check git push commands targeting main/master
if ! echo "$CMD" | grep -qE 'git[[:space:]]+push.*(main|master)'; then
  exit 0
fi

ALLOWLIST="$HOME/.claude/hooks/push-main-allowed-repos"

if [[ -f "$ALLOWLIST" ]]; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  while IFS= read -r allowed; do
    # Skip blank lines and comments
    [[ -z "$allowed" || "$allowed" == \#* ]] && continue
    if [[ "$allowed" == cmd-contains:* ]]; then
      pat="${allowed#cmd-contains:}"
      pat="${pat# }"
      [[ -n "$pat" && "$CMD" == *"$pat"* ]] && exit 0
      continue
    fi
    # Expand ~ to $HOME
    allowed="${allowed/#\~/$HOME}"
    if [[ "$repo_root" == "$allowed" ]]; then
      exit 0
    fi
  done < "$ALLOWLIST"
fi

echo "BLOCKED: Use feature branches, not direct push to main. Add repo to ~/.claude/hooks/push-main-allowed-repos to allow." >&2
exit 2
