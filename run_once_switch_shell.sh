#!/bin/sh

# Switch to using brew-installed zsh as default shell
if ! fgrep -q '/opt/homebrew/bin/fish' /etc/shells; then
  echo '/opt/homebrew/bin/fish' | sudo tee -a /etc/shells;
  chsh -s /opt/homebrew/bin/fish;
fi;

