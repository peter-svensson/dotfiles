# Enable instant history sharing across all Fish sessions
# This is especially important for tmux with multiple panes/windows

# Save history immediately after each command
function __fish_save_history_on_prompt --on-event fish_prompt
    history save
end

# Merge history from other sessions before executing a command
function __fish_merge_history_on_preexec --on-event fish_preexec
    history merge
end
