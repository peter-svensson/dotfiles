#!/bin/sh
# Claude Code hook: send bell on Stop and Notification events
# Bell triggers tmux monitor-bell (window coloring) and alert-bell (macOS notification)

# Only notify if inside a tmux session
[ -z "$TMUX" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0

# Get the tty of the pane running Claude
pane_tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}')
[ -z "$pane_tty" ] && exit 0

event=$(cat | jq -r '.hook_event_name // empty')

case "$event" in
    Stop|Notification)
        printf '\a' > "$pane_tty"
        ;;
esac
