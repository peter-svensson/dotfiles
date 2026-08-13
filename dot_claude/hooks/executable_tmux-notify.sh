#!/bin/sh
# Claude Code hook: send bell on Stop and Notification events
# Bell triggers tmux monitor-bell (window coloring) and alert-bell (macOS notification)
#
# Also records what kind of attention this agent wants in @agent: blocked
# (waiting on a permission prompt, so the agent is idle) or done (turn finished).
#
# @agent is pane-scoped (-p), not window-scoped: several agents commonly share
# one window, and a window-scoped value would be last-writer-wins and get
# cleared for every agent as soon as any one pane is focused. The status bar
# aggregates the panes of each window with #{P:} instead.
#
# pane-border-style is also a pane option (tmux 3.2+), so the same state colours
# the individual agent's border inside the window. Borders only draw when a
# window is split; single-pane windows rely on the status bar alone.
#
# @bell stays the window-scoped "needs attention" flag driving tmux-jump-bell
# and the macOS notification; alert-bell fires after this script, so a state
# written into @bell would be clobbered.

# Only notify if inside a tmux session
[ -z "$TMUX" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0

# Get the tty of the pane running Claude
pane_tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}')
[ -z "$pane_tty" ] && exit 0

event=$(cat | jq -r '.hook_event_name // empty')

case "$event" in
    Notification)
        tmux set-option -p -t "$TMUX_PANE" @agent blocked
        tmux set-option -p -t "$TMUX_PANE" pane-border-style 'fg=colour1,bold'
        printf '\a' > "$pane_tty"
        ;;
    Stop)
        tmux set-option -p -t "$TMUX_PANE" @agent 'done'
        tmux set-option -p -t "$TMUX_PANE" pane-border-style 'fg=colour2'
        printf '\a' > "$pane_tty"
        ;;
esac
