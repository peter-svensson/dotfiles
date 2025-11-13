# conf.d runs first!

# https://fishshell.com/docs/current/tutorial.html
# https://github.com/jorgebucaran/fish-shell-cookbook
# https://github.com/fish-shell/fish-shell/blob/master/share/config.fish
# https://github.com/fish-shell/fish-shell/blob/da32b6c172dcfe54c9dc4f19e46f35680fc8a91a/share/config.fish#L257-L269

if status is-interactive
  # Only cd to HOME if not in tmux (to preserve tmux-resurrect working directories)
  if not set -q TMUX
    cd $HOME
  end
end

#
# Utils
#

# Initialize direnv.
if type -q direnv
  direnv hook fish | source
end

#
# Prompt
#

# Disable new user greeting.
set fish_greeting

# Initialize starship.
if type -q starship
  set -gx STARSHIP_CONFIG $__fish_config_dir/themes/starship.toml
  if not test -r $__fish_cache_dir/starship_init.fish
      starship init fish --print-full-init >$__fish_cache_dir/starship_init.fish
  end
  source $__fish_cache_dir/starship_init.fish
  enable_transience
end

#
# Theme
#

fish_config theme choose $FISH_THEME

#
# Tmux
#
status is-interactive; and begin
  set fish_tmux_default_session_name default
  set fish_tmux_autostart_once true
  set fish_tmux_autostart true
  set fish_tmux_autoconnect true
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
