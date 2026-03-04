function mdview --description "Render markdown with glow, full colors, in a pager"
    if test (count $argv) -eq 0
        echo "Usage: mdview <file.md>" >&2
        return 1
    end

    if not test -f "$argv[1]"
        echo "mdview: file not found: $argv[1]" >&2
        return 1
    end

    # script -q forces TTY so glow emits full 256-color output.
    # tail strips the leading control char artifact from script.
    # -K lets Ctrl-C quit less.
    script -q /dev/null glow -s dark "$argv[1]" 2>/dev/null | tail -n +2 | less -RK
end
