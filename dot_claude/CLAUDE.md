- When spawning agents/subprocesses that need the `claude` binary, always use `/opt/homebrew/bin/claude` (the stable symlink), NEVER the versioned Caskroom path (`/opt/homebrew/Caskroom/claude-code/<version>/claude`) which breaks on upgrades
- always unzip files to a temporary directory
- Always add all files to git before running pre-commit since it stashes all unstaged files when running
- I use GNU versions of rm and cp which ask for confirmation on replace and remove.
- Always explicitly specify the context when running `kubectl` commands using `--context <context>`. Check the project's `.buildtools.yaml` or `.envrc` for the expected k8s context. Never rely on the current default context — it may point to a different cluster (e.g., production instead of local). For local development, the context typically follows the pattern: `kind-<project-name>`

