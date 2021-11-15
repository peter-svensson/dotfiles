# Xcode command line tools
```bash
xcode-select --install
````

# Rosetta
```bash
sudo softwareupdate --install-rosetta
```

# Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

# chezmoi
```bash
brew install chezmoi
brew install lastpass-cli
lpass login peter@sparetimecoders.com
```

```bash
chezmoi init --apply peter-svensson
```

## Adding stuff to Lastpass

```bash
echo "$(cat ~/.gnupg/pubring.kbx | base64)" | lpass add --sync=now --non-interactive --notes "lambda/gnupg-pubring.kbx"
```

### SSH keys
```bash
printf "Private Key: %s\nPublic Key: %s" "$(cat ~/.ssh/id_rsa_plint_git)" "$(cat ~/.ssh/id_rsa_plint_git.pub)" | lpass add --sync=now --non-interactive --note-type=ssh-key "plint/git ssh key"
```