#!/bin/sh
# Claude Code hook: report agent state to the terminal multiplexer.
#
# Rex: writes an OSC 7501 program status report to the Claude pane. Rex itself
# turns that into tab indicators, macOS notifications, the Dock badge, sounds
# and the Activity sidebar (cmd+.), so nothing else is needed here.
# Spec: https://www.superlogical.com/rex/docs/build/program-status
#
# tmux: sends a bell on Stop, StopFailure and Notification events. The bell
# triggers tmux monitor-bell (window coloring) and alert-bell (macOS
# notification).
#
# Also records what kind of attention this agent wants in @agent: blocked
# (waiting on a permission prompt, so the agent is idle), done (turn finished)
# or error (turn ended on an API error: 529 overloaded, rate limit, outage).
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

event=$(jq -r '.hook_event_name // empty')

# Hooks run without a controlling terminal, so walk up the process tree to
# the first ancestor that has one: the Claude process itself.
claude_tty() {
    pid=$PPID
    depth=0
    while [ "$pid" -gt 1 ] && [ "$depth" -lt 8 ]; do
        tty=$(ps -o tty= -p "$pid" | tr -d ' ')
        case "$tty" in
            '' | '??') ;;
            *) echo "/dev/$tty"; return 0 ;;
        esac
        pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
        depth=$((depth + 1))
    done
    return 1
}

rex_status() {
    tty=$(claude_tty) || exit 0
    case "$event" in
        UserPromptSubmit | PostToolUse) state='working' ;;
        Notification) state='blocked:kind=permission' ;;
        Stop) state='done' ;;
        StopFailure) state='error' ;;
        *) exit 0 ;;
    esac
    printf '\033]7501;state=%s:app=claude-code\033\134' "$state" > "$tty"
}

if [ -n "$REX_BLOCK" ]; then
    rex_status
    exit 0
fi

# Only notify if inside a tmux session
[ -z "$TMUX" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0

# Get the tty of the pane running Claude
pane_tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}')
[ -z "$pane_tty" ] && exit 0

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
    StopFailure)
        tmux set-option -p -t "$TMUX_PANE" @agent error
        tmux set-option -p -t "$TMUX_PANE" pane-border-style 'fg=colour3,bold'
        printf '\a' > "$pane_tty"
        ;;
esac
