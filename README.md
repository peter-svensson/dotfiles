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
```

```bash
chezmoi init --apply peter-svensson
```

## Secrets Management (Proton Pass)

Secrets are managed via Proton Pass using chezmoi's built-in `protonPass` and `protonPassJSON` template functions.

Ensure the Proton Pass CLI is installed and authenticated before running `chezmoi apply`.