#!/bin/sh

# Switch to using brew-installed zsh as default shell
if ! fgrep -q '/opt/homebrew/bin/zsh' /etc/shells; then
  echo '/opt/homebrew/bin/zsh' | sudo tee -a /etc/shells;
  chsh -s /opt/homebrew/bin/zsh;
fi;

