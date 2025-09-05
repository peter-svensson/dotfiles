function grep --wraps='grep' --description 'alias grep command grep --color=auto'
    command grep --color=auto $argv
end
