function bup -d "Update homebrew, upgrade installed packages, and cleanup"
  set -l file "$HOME/.local/share/Brewfile"

  echo "Checking Brewfile"
  set -l result (brew bundle cleanup --file $file)
  if test $status -ne 0
    if test (echo "$result" | grep -c 'uninstall') -gt 0
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
  set -l caskroom (brew --caskroom)
  for cask in (brew list --cask)
    brew info --cask $cask --json=v2 \
    | jq -r '.casks[0] | [(.outdated | tostring), (.installed // "NONE"), .version] | @tsv' \
    | read outdated installed current && if test "$installed" = NONE
      echo "Fixing $cask: brew lost track of installed version"
      brew install --cask --force $cask; or echo "Warning: failed to install $cask, skipping"
    else if test "$current" != "$installed"
      echo "Upgrading $cask from $installed to $current"
      set -l manual_installer (brew info --cask $cask --json=v2 \
        | jq -r '.casks[0].artifacts[] | select(.installer) | .installer[] | select(.manual) | .manual // empty')
      # Clean up old version directories that block upgrades
      for old_ver in (command ls -1 "$caskroom/$cask/" 2>/dev/null)
        if test "$old_ver" != "$current"
          echo "Removing old caskroom version: $cask/$old_ver"
          command rm -rf "$caskroom/$cask/$old_ver"
        end
      end
      if test -n "$manual_installer"
        if brew reinstall --cask --force $cask
          set -l installer_path "$caskroom/$cask/$current/$manual_installer"
          if test -e "$installer_path"
            echo "Opening manual installer: $installer_path"
            open "$installer_path"
          else
            echo "Warning: installer not found at $installer_path"
            echo "Check $caskroom/$cask/ manually"
          end
        else
          echo "Warning: failed to reinstall $cask, skipping"
        end
      else
        brew upgrade --cask --greedy $cask; or echo "Warning: failed to upgrade $cask, skipping"
      end
    else
      echo "$cask:$current is latest version"
    end
  end
end
