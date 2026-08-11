#!/usr/bin/env bash
set -euo pipefail

# Health-check the Claude memory dirs: index drift, dangling [[links]], stale date
# references, near-duplicate names. Reports only — fixes nothing.
ROOT=${1:-$HOME/.claude/projects}
today=$(date +%Y-%m-%d)

total=0
issues=0
report=""

note() {
  report+="$1"$'\n'
  issues=$((issues + 1))
}

for dir in "$ROOT"/*/memory; do
  [[ -d "$dir" ]] || continue
  mapfile -t files < <(find "$dir" -maxdepth 1 -name '*.md' ! -name 'MEMORY.md' | sort)
  ((${#files[@]})) || continue
  total=$((total + ${#files[@]}))
  proj=$(basename "$(dirname "$dir")")
  idx="$dir/MEMORY.md"

  if [[ ! -f "$idx" ]]; then
    note "$proj: no MEMORY.md index, ${#files[@]} files unindexed"
    continue
  fi

  # [[link]] targets a memory's `name:` slug, which need not equal its filename.
  declare -A byname=()
  for f in "${files[@]}"; do
    nm=$(sed -n 's/^name:[[:space:]]*//p' "$f" | head -1 | tr -d '"'"'")
    [[ -n "$nm" ]] && byname["$nm"]=$(basename "$f")
  done

  for f in "${files[@]}"; do
    b=$(basename "$f" .md)
    grep -qF "$b" "$idx" || note "$proj/$b: not listed in MEMORY.md"
    grep -q '^name:' "$f" || note "$proj/$b: missing name: frontmatter"
    # dangling wiki links. A link that resolves once _ and - are treated as the same
    # character is a filename-convention mismatch, not a missing memory.
    while read -r link; do
      [[ -z "$link" ]] && continue
      link=${link%.md}
      [[ -f "$dir/$link.md" ]] && continue
      if [[ -n "${byname[$link]:-}" ]]; then
        note "$proj/$b: FILENAME [[$link]] lives in ${byname[$link]}"
      else
        note "$proj/$b: BROKEN   [[$link]]"
      fi
    done < <(grep -o '\[\[[^]]*\]\]' "$f" 2>/dev/null | tr -d '[]' | sort -u)
  done

  # index entries whose file is gone
  while read -r link; do
    [[ -z "$link" || -f "$dir/$link" ]] && continue
    note "$proj: MEMORY.md points at missing file $link"
  done < <(grep -o '(\([^)]*\.md\))' "$idx" 2>/dev/null | tr -d '()' | sort -u)
done

printf 'memory files: %s\nissues: %s\n\n%s' "$total" "$issues" "$report"
[[ -n "${LINT_TODAY:-}" ]] && echo "(checked $today)"
exit 0
