function open --description "Open files, using glow for markdown in the terminal"
    for file in $argv
        switch $file
            case "*.md" "*.markdown" "*.mdown" "*.mkd"
                glow --tui $file
            case '*'
                command open $file
        end
    end
end
