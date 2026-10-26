# conf.d runs first!

# Force CLI tools to use English regardless of macOS language settings
set -gx LANGUAGE en_US.UTF-8

# https://fishshell.com/docs/current/tutorial.html
# https://github.com/jorgebucaran/fish-shell-cookbook
# https://github.com/fish-shell/fish-shell/blob/master/share/config.fish
# https://github.com/fish-shell/fish-shell/blob/da32b6c172dcfe54c9dc4f19e46f35680fc8a91a/share/config.fish#L257-L269

if status is-interactive
  # Only cd to HOME outside a multiplexer, so tmux-resurrect and Rex splits keep their cwd
  if not set -q TMUX; and not set -q REX_BLOCK
    cd $HOME
  end
  # Rex puts its own rex CLI first in PATH; keep it there after conf.d reorders PATH
  if set -q REX_BIN_DIR
    fish_add_path --path --prepend --move $REX_BIN_DIR
  end
end

#
# Utils
#

# Initialize fnm after cd $HOME so the --use-on-cd hook has PATH set up correctly.
if type -q fnm
  fnm env --use-on-cd --shell fish | source
end

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
  if not test -s $__fish_cache_dir/starship_init.fish
      starship init fish --print-full-init >$__fish_cache_dir/starship_init.fish
  end
  if test -s $__fish_cache_dir/starship_init.fish
      source $__fish_cache_dir/starship_init.fish
      enable_transience
  end
end

#
# Theme
#

fish_config theme choose $FISH_THEME

#
# Tmux
#
# Rex is the multiplexer in Rex terminals; no tmux inside it
status is-interactive; and not set -q REX_BLOCK; and begin
  set fish_tmux_default_session_name default
  set fish_tmux_autostart_once true
  set fish_tmux_autostart true
  set fish_tmux_autoconnect true
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Scaleway CLI autocomplete initialization.
eval (scw autocomplete script shell=fish)

