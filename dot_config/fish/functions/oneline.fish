function oneline -d "Convert multiline input to single line with literal \\n"
    cat $argv | string join '\n'
end
