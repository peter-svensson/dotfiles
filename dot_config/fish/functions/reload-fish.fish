function reload-fish --description "Reload Fish configuration in all tmux panes"
    # Check if we're in tmux
    if not set -q TMUX
        echo "Reloading current Fish session..."
        echo "Note: For event handlers to work, restart Fish with: exec fish"
        source ~/.config/fish/config.fish
        echo "✓ Fish config reloaded"
        return
    end

    # Restart all tmux panes running Fish
    echo "Restarting Fish in all tmux panes..."

    set panes_reloaded 0

    for line in (tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}')
        set pane (echo $line | cut -d' ' -f1)
        set cmd (echo $line | cut -d' ' -f2)

        if test "$cmd" = "fish"
            # Use exec to replace the current shell process with a new one
            # This properly reloads all event handlers
            tmux send-keys -t "$pane" "exec fish" C-m
            set panes_reloaded (math $panes_reloaded + 1)
        end
    end

    echo "✓ Restarted Fish in $panes_reloaded pane(s)"
end
