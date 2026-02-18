abbr -a -- nv nvim

abbr -a -- cm chezmoi
abbr -a -- rf reload-fish

# Terraform
abbr -a -- tf terraform
abbr -a -- tff terraform fmt -recursive

abbr -a -- sso aws-sso-profile

abbr -a -- k kubectl
abbr -a -- kc kubectl --context
abbr -a -- sc stern --context

abbr -a -- gup git up
abbr -a -- ggone "git branch -vv | grep ': gone]' | awk '{print \$1}' | xargs git branch -D"
