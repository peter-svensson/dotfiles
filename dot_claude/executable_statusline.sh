#!/bin/bash
# Two-line statusline with visual context progress bar
#
# Line 1: Model, folder, branch
# Line 2: Progress bar, context %, cost, duration
#
# Context % uses Claude Code's pre-calculated remaining_percentage,
# which accounts for compaction reserves. 100% = compaction fires.

# Read stdin (Claude Code passes JSON data via stdin)
stdin_data=$(cat)

# Single jq call - extract all values at once
# Prefer pre-calculated remaining_percentage (100 - remaining = used toward compact)
# Fall back to manual calc from raw tokens if not available
IFS=$'\t' read -r current_dir model_name cost lines_added lines_removed duration_ms ctx_used cache_pct < <(
    echo "$stdin_data" | jq -r '[
        .workspace.current_dir // "unknown",
        .model.display_name // "Unknown",
        (try (.cost.total_cost_usd // 0 | . * 100 | floor / 100) catch 0),
        (.cost.total_lines_added // 0),
        (.cost.total_lines_removed // 0),
        (.cost.total_duration_ms // 0),
        (try (
            if (.context_window.remaining_percentage // null) != null then
                100 - (.context_window.remaining_percentage | floor)
            elif (.context_window.context_window_size // 0) > 0 then
                (((.context_window.current_usage.input_tokens // 0) +
                  (.context_window.current_usage.cache_creation_input_tokens // 0) +
                  (.context_window.current_usage.cache_read_input_tokens // 0)) * 100 /
                 .context_window.context_window_size) | floor
            else "null" end
        ) catch "null"),
        (try (
            (.context_window.current_usage // {}) |
            if (.input_tokens // 0) + (.cache_read_input_tokens // 0) > 0 then
                ((.cache_read_input_tokens // 0) * 100 /
                 ((.input_tokens // 0) + (.cache_read_input_tokens // 0))) | floor
            else 0 end
        ) catch 0)
    ] | @tsv'
)

# Bash-level fallback: if jq crashed entirely, extract fields individually
if [ -z "$current_dir" ] && [ -z "$model_name" ]; then
    current_dir=$(echo "$stdin_data" | jq -r '.workspace.current_dir // .cwd // "unknown"' 2>/dev/null)
    model_name=$(echo "$stdin_data" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)
    cost=$(echo "$stdin_data" | jq -r '(.cost.total_cost_usd // 0)' 2>/dev/null)
    lines_added=$(echo "$stdin_data" | jq -r '(.cost.total_lines_added // 0)' 2>/dev/null)
    lines_removed=$(echo "$stdin_data" | jq -r '(.cost.total_lines_removed // 0)' 2>/dev/null)
    duration_ms=$(echo "$stdin_data" | jq -r '(.cost.total_duration_ms // 0)' 2>/dev/null)
    ctx_used=""
    cache_pct="0"
    : "${current_dir:=unknown}"
    : "${model_name:=Unknown}"
    : "${cost:=0}"
    : "${lines_added:=0}"
    : "${lines_removed:=0}"
    : "${duration_ms:=0}"
fi

# Git info
if cd "$current_dir" 2>/dev/null; then
    git_branch=$(git -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
    git_root=$(git -c core.useBuiltinFSMonitor=false rev-parse --show-toplevel 2>/dev/null)
fi

# Git status markers (starship-style): ✓ clean, ⇡N ahead, ⇣N behind, ! dirty
git_status_marker=""
if [ -n "$git_branch" ]; then
    ahead_behind=$(git -c core.useBuiltinFSMonitor=false rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
    if [ -n "$ahead_behind" ]; then
        behind_count=$(echo "$ahead_behind" | cut -f1)
        ahead_count=$(echo "$ahead_behind" | cut -f2)
    else
        behind_count=0
        ahead_count=0
    fi
    is_dirty=$(git -c core.useBuiltinFSMonitor=false status --porcelain 2>/dev/null)

    marker=""
    if [ "$ahead_count" -gt 0 ] 2>/dev/null; then
        marker="$marker$(printf '\033[32m⇡%s\033[0m' "$ahead_count")"
    fi
    if [ "$behind_count" -gt 0 ] 2>/dev/null; then
        marker="$marker$(printf '\033[31m⇣%s\033[0m' "$behind_count")"
    fi
    if [ -n "$is_dirty" ]; then
        marker="$marker$(printf '\033[33m!\033[0m')"
    fi
    if [ -z "$marker" ]; then
        marker=$(printf '\033[32m✓\033[0m')
    fi
    git_status_marker="$marker"
fi

# Build repo path display (folder name only for brevity)
if [ -n "$git_root" ]; then
    repo_name=$(basename "$git_root")
    if [ "$current_dir" = "$git_root" ]; then
        folder_name="$repo_name"
    else
        folder_name=$(basename "$current_dir")
    fi
else
    folder_name=$(basename "$current_dir")
fi

# Generate visual progress bar for context usage
progress_bar=""
bar_width=12

if [ -n "$ctx_used" ] && [ "$ctx_used" != "null" ]; then
    filled=$((ctx_used * bar_width / 100))
    empty=$((bar_width - filled))

    if [ "$ctx_used" -lt 50 ]; then
        bar_color='\033[32m'  # Green (0-49%)
    elif [ "$ctx_used" -lt 80 ]; then
        bar_color='\033[33m'  # Yellow (50-79%)
    else
        bar_color='\033[31m'  # Red (80-100%)
    fi

    progress_bar="${bar_color}"
    for ((i=0; i<filled; i++)); do
        progress_bar="${progress_bar}█"
    done
    progress_bar="${progress_bar}\033[2m"
    for ((i=0; i<empty; i++)); do
        progress_bar="${progress_bar}⣿"
    done
    progress_bar="${progress_bar}\033[0m"

    ctx_pct="${ctx_used}%"
else
    ctx_pct=""
fi

# Session time (human-readable)
if [ "$duration_ms" -gt 0 ] 2>/dev/null; then
    total_sec=$((duration_ms / 1000))
    hours=$((total_sec / 3600))
    minutes=$(((total_sec % 3600) / 60))
    seconds=$((total_sec % 60))
    if [ "$hours" -gt 0 ]; then
        session_time="${hours}h ${minutes}m"
    elif [ "$minutes" -gt 0 ]; then
        session_time="${minutes}m ${seconds}s"
    else
        session_time="${seconds}s"
    fi
else
    session_time=""
fi

# SCW_PROFILE (starship-style): purple, 🪐 prefix, only when set
scw_segment=""
if [ -n "$SCW_PROFILE" ]; then
    scw_segment=$(printf '\033[35m🪐 %s\033[0m' "$SCW_PROFILE")
fi

# Kubernetes context/namespace (starship-style):  symbol, "context (namespace)"
# Cheap file read only — never shell out to kubectl on every render.
k8s_segment=""
# KUBECONFIG may be a colon-separated LIST of files (it is on this machine).
# kubectl merges them and the first file setting current-context wins, so take
# the first readable entry that declares one.
# Take the first entry that declares a NON-EMPTY context: several files here
# carry `current-context: ""` or leave it blank, and those must not win.
kube_config=""
k8s_context=""
for candidate in $(printf '%s' "${KUBECONFIG:-$HOME/.kube/config}" | tr ':' ' '); do
    [ -f "$candidate" ] || continue
    candidate_ctx=$(awk '/^current-context:/ { print $2; exit }' "$candidate" 2>/dev/null | tr -d '"'"'"'')
    if [ -n "$candidate_ctx" ]; then
        kube_config="$candidate"
        k8s_context="$candidate_ctx"
        break
    fi
done
if [ -n "$kube_config" ]; then
    if [ -n "$k8s_context" ]; then
        # Find the "- name: <ctx>" entry under contexts:, then take the first
        # "namespace:" before the next "- name:". Context entries are indented
        # under `contexts:`, so match the dash anywhere on the line and compare
        # the field after "name:" rather than a fixed column.
        k8s_namespace=$(awk -v ctx="$k8s_context" '
            /^[[:space:]]*-[[:space:]]*name:/ {
                sub(/^[^:]*:[[:space:]]*/, "")
                in_target = ($0 == ctx)
                next
            }
            in_target && /^[[:space:]]*namespace:/ { print $2; exit }
        ' "$kube_config" 2>/dev/null)
        if [ -n "$k8s_namespace" ]; then
            k8s_segment=$(printf '\033[36m %s (%s)\033[0m' "$k8s_context" "$k8s_namespace")
        else
            k8s_segment=$(printf '\033[36m %s\033[0m' "$k8s_context")
        fi
    fi
fi

# Separator
SEP='\033[2m│\033[0m'

# Get short model name (e.g., "Opus" instead of "Claude 3.5 Opus")
short_model=$(echo "$model_name" | sed -E 's/Claude [0-9.]+ //; s/^Claude //')

# Caveman badge — read current mode from flag file written by caveman hooks.
# Apply upstream security guards: refuse symlinks, cap read length, allowlist mode.
caveman_badge=""
caveman_flag="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-active"
if [ -f "$caveman_flag" ] && [ ! -L "$caveman_flag" ]; then
    caveman_mode=$(head -c 64 "$caveman_flag" 2>/dev/null | tr -d '\n\r' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
    case "$caveman_mode" in
        off) ;;
        full|"") caveman_badge=$(printf '\033[38;5;172m[CAVEMAN]\033[0m') ;;
        lite|ultra|wenyan-lite|wenyan|wenyan-full|wenyan-ultra|commit|review|compress)
            caveman_suffix=$(printf '%s' "$caveman_mode" | tr '[:lower:]' '[:upper:]')
            caveman_badge=$(printf '\033[38;5;172m[CAVEMAN:%s]\033[0m' "$caveman_suffix")
            ;;
    esac
fi

# LINE 1: [Caveman] [Model] folder | branch
line1=$(printf '\033[37m[%s]\033[0m' "$short_model")
if [ -n "$caveman_badge" ]; then
    line1="$caveman_badge $line1"
fi
line1="$line1 $(printf '\033[94m📁 %s\033[0m' "$folder_name")"
# Branch name is noise on main - but its status markers are not.
if [ -n "$git_branch" ] && [ "$git_branch" != "main" ]; then
    line1="$line1 $(printf '%b \033[32m %s\033[0m' "$SEP" "$git_branch")"
    if [ -n "$git_status_marker" ]; then
        line1="$line1 $(printf '%b' "$git_status_marker")"
    fi
elif [ -n "$git_status_marker" ]; then
    line1="$line1 $(printf '%b %b' "$SEP" "$git_status_marker")"
fi
if [ -n "$scw_segment" ]; then
    line1="$line1 $(printf '%b %b' "$SEP" "$scw_segment")"
fi
if [ -n "$k8s_segment" ]; then
    line1="$line1 $(printf '%b %b' "$SEP" "$k8s_segment")"
fi

# LINE 2: Progress bar | Context % | cost | duration
line2=""
if [ -n "$progress_bar" ]; then
    line2=$(printf '%b' "$progress_bar")
fi
if [ -n "$ctx_pct" ]; then
    if [ -n "$line2" ]; then
        line2="$line2 $(printf '\033[37m%s\033[0m' "$ctx_pct")"
    else
        line2=$(printf '\033[37m%s\033[0m' "$ctx_pct")
    fi
fi
if [ -n "$line2" ]; then
    line2="$line2 $(printf '%b \033[33m$%s\033[0m' "$SEP" "$cost")"
else
    line2=$(printf '\033[33m$%s\033[0m' "$cost")
fi
if [ -n "$session_time" ]; then
    line2="$line2 $(printf '%b \033[36m⏱ %s\033[0m' "$SEP" "$session_time")"
fi
if [ "$cache_pct" -gt 0 ] 2>/dev/null; then
    line2="$line2 $(printf ' \033[2m↻%s%%\033[0m' "$cache_pct")"
fi

printf '%b\n\n%b' "$line1" "$line2"
