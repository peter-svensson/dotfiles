function bup -d "Update homebrew, upgrade installed packages, and cleanup"
  set -l file "$HOME/.local/share/Brewfile"

  echo "Checking Brewfile"
  set -l result $(brew bundle cleanup --file $file)
  if test $status -ne 0
    if test $(echo "$result" | grep -c 'uninstall') -gt 0
      echo "Missing installed dependencies in Brewfile $file"
      echo "Update before running again"
      string join \n $result
      return
    else
      echo "Errors in Brewfile $file?"
      echo "Fix them and try again"
      return
    end
  end

  echo "Brewfile matches installation, updating packages"
  brew update && brew upgrade && brew cleanup
  for cask in $(brew list --cask)
    brew info --cask $cask --json=v2 \
    | jq -r "[.casks[].outdated,.casks[].installed,.casks[].version] \
    | @tsv" \
    | read outdated installed current && if test "$current" != "$installed"
      echo "Upgrading $cask from $installed to $current"
      brew upgrade --cask --greedy $cask
    else
      echo "$cask:$current is latest version"
    end
  end
end
