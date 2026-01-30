# Completions for but-pull-all

# Project name completion
complete -c but-pull-all -f -a '(jq -r ".[].path" "$HOME/Library/Application Support/com.gitbutler.app/projects.json" 2>/dev/null | xargs -I{} basename {} | sort -u)'

# Flags
complete -c but-pull-all -s f -l force -d 'Clean broken refs automatically'
