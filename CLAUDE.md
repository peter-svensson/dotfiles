# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a chezmoi dotfiles repository for managing personal configuration across macOS machines. The repository uses chezmoi's templating system to manage environment-specific configurations, secrets integration with LastPass, and multi-organization workspace support.

## Key Architecture Concepts

### Chezmoi File Naming Convention

Chezmoi uses special prefixes in filenames to determine how files are managed:

- `dot_` → Becomes `.` (e.g., `dot_bashrc` → `.bashrc`)
- `private_` → File permissions set to 0600 (private files only readable by owner)
- `executable_` → File permissions include execute bit
- `run_once_` → Script that runs once during `chezmoi apply`
- `empty_` → Creates an empty file
- `.tmpl` suffix → File is processed as a Go template with access to chezmoi data

Combinations are allowed: `private_dot_ssh/config` → `~/.ssh/config` with 0600 permissions

### Multi-Organization Workspace Structure

The `source/` directory contains organization-specific configurations:
- `source/stc/` - Spare Time Coders
- `source/keenfinity/` - Keenfinity
- `source/lifeinside/` - Life Inside
- `source/producttale/` - Product Tale
- `source/opzkit/` - OpzKit
- `source/goodfeed/` - GoodFeed
- `source/intersolia/` - Intersolia

Each organization directory contains:
- `dot_aws/` - AWS configuration
- `dot_aws-sso/` - AWS SSO configuration
- `dot_envrc` or `dot_envrc.tmpl` - direnv environment variables
- `dot_kube/` - Kubernetes configurations (when applicable)
- `dot_gitconfig.tmpl` - Git config overrides (when applicable)

### Template System

Templates use Go's text/template syntax with chezmoi-specific functions:

- `{{ .chezmoi.hostname }}` - Current hostname
- `{{ .chezmoi.homeDir }}` - Home directory path
- `{{ .chezmoi.os }}` - Operating system
- `{{ lastpass "path/to/secret" }}` - Retrieve secrets from LastPass
- `{{ include "path" }}` - Include file contents
- `{{ joinPath .chezmoi.homeDir "path" }}` - Build file paths

### Secrets Management

Secrets are retrieved from LastPass using the `lastpass` template function:
```
{{ (index (lastpass "devenv/auths") 0).note.githubToken }}
```

SSH keys, GPG keys, and credentials are stored in LastPass and templated into the appropriate files during `chezmoi apply`.

### Conditional Configuration

The `.chezmoiignore` file uses templates to conditionally include/exclude files based on hostname:
```
{{- if eq .chezmoi.hostname "A6436903" }}
source/*
!source/jeppesen
{{ else }}
source/jeppesen
{{- end }}
```

## Common Commands

### Testing Changes

```bash
# See what changes would be applied without applying them
chezmoi diff

# Preview changes in detail
chezmoi apply --dry-run --verbose
```

### Applying Changes

```bash
# Apply all changes
chezmoi apply

# Apply changes for specific file
chezmoi apply ~/.gitconfig

# Force re-run of run_once scripts
chezmoi state delete-bucket --bucket=scriptState
```

### Editing Files

```bash
# Edit a file in the chezmoi source directory
chezmoi edit ~/.bashrc

# Edit and apply immediately
chezmoi edit --apply ~/.gitconfig

# Add a new file to chezmoi
chezmoi add ~/.config/newfile
```

### Managing the Repository

```bash
# Change to the chezmoi source directory
chezmoi cd

# Pull and apply changes from remote
chezmoi update

# View current chezmoi data (useful for template debugging)
chezmoi data

# Re-run package installation (updates Brewfile hash)
chezmoi apply --force --verbose run_once_000_install-packages-darwin.sh.tmpl
```

### Template Testing

```bash
# Execute a template to see the output
chezmoi execute-template '{{ .chezmoi.hostname }}'

# View the target contents of a template file
chezmoi cat ~/.gitconfig
```

## Development Workflow

### Adding Organization-Specific Configuration

When adding configuration for a new project/organization:

1. Create directory in `source/{org-name}/`
2. Add required files:
   - `dot_aws/config` - AWS profiles
   - `dot_aws-sso/config` - AWS SSO configuration
   - `dot_envrc` or `dot_envrc.tmpl` - Environment variables
3. Use `source_up .envrc` in organization envrc to inherit global settings
4. Update `.chezmoiignore` if the config should only apply to specific machines

### Modifying Package Installations

Edit `dot_local/share/Brewfile` to add/remove Homebrew packages, casks, or Go tools. The installation script automatically detects changes via hash comparison.

Format:
```
brew "package-name"
cask "application-name"
go "go-package-import-path"
```

### Node.js Version Management with direnv

For projects that specify Node versions in `package.json` rather than `.nvmrc`, use the `use_fnm` function in `.envrc`:

```bash
# .envrc example
source_up

# Use Node version from package.json engines.node field
use fnm package.json

# Or use explicit version
use fnm 20

# Or read from .nvmrc if present
use fnm
```

**Backward compatibility**: `use_nvm` is aliased to `use_fnm`, so both work identically. Legacy `.envrc` files don't need updating.

After creating or modifying `.envrc`:
```bash
direnv allow
```

### Working with Templates

When editing `.tmpl` files:
1. Use `chezmoi edit` to edit the source template
2. Use `chezmoi cat` to preview the rendered output
3. Use `chezmoi apply --dry-run` to test before applying
4. Test LastPass integration by ensuring `lpass login` is active

### SSH and GPG Key Management

SSH keys are stored as templates referencing LastPass:
- Public keys: `id_rsa.pub.tmpl`, `keen_id_rsa.pub.tmpl`, etc.
- Private keys: `private_id_rsa.tmpl`, `private_keen_id_rsa.tmpl`, etc.

GPG configuration is stored in `private_dot_gnupg/` with similar LastPass integration.

## Important Files

- `.chezmoiexternal.toml` - External resource management (tmux plugins, Hammerspoon spoons)
- `.chezmoiignore` - Files to exclude from chezmoi management
- `run_once_000_install-packages-darwin.sh.tmpl` - Package installation bootstrap
- `run_once_zz_modify_macos.sh` - macOS system preferences automation
- `dot_gitconfig.tmpl` - Global Git configuration with SSH signing
- `dot_config/fish/config.fish` - Fish shell configuration
- `dot_local/share/Brewfile` - Homebrew package definitions

## Shell Environment

The primary shell is Fish (with Bash as fallback for scripts and compatibility). Key features:
- Starship prompt with transience enabled
- direnv integration for per-directory environment variables
- tmux auto-start with session management
- fisher for Fish plugin management
- fnm (Fast Node Manager) for automatic Node.js version switching

Configuration locations:
- `dot_config/fish/config.fish` - Main Fish config
- `dot_config/fish/conf.d/` - Auto-loaded configuration snippets
- `dot_config/fish/conf.d/fnm.fish` - fnm initialization with auto-switching
- `dot_config/fish/functions/` - Custom Fish functions
- `dot_bashrc` - Bash configuration (synchronized PATH with Fish for script compatibility)

## Node.js Version Management

Uses fnm (Fast Node Manager) instead of nvm for faster performance and automatic version switching.

**Automatic switching**: fnm automatically switches Node versions when entering directories with `.nvmrc` or `.node-version` files.

**Common commands**:
```bash
# Install Node version
fnm install 20
fnm install --lts

# List installed versions
fnm list

# Manually switch version
fnm use 20
```

**Configuration**: `dot_config/fish/conf.d/fnm.fish` enables `--use-on-cd` for automatic version switching based on `.nvmrc` files.

## PATH Synchronization

Both Fish and Bash are configured with synchronized PATH settings to ensure scripts run correctly regardless of shell:

**Common PATH components** (in order of precedence):
1. Homebrew environment (`/opt/homebrew/bin`, etc.)
2. GNU tools (override macOS BSD tools): `make`, `coreutils`, `findutils`, `gnu-sed`, `grep`
3. Custom binaries: `~/.local/bin`, `~/.gobrew/current/bin`, `~/go/bin`, `~/bin`
4. fnm Node.js versions
5. direnv integration

**Important**: When modifying PATH in Fish config, also update `dot_bashrc` to maintain synchronization for Bash scripts.
