function but-pull-all --description "Update all GitButler projects to latest remote state"
    argparse 'f/force' 't/timeout=!_validate_int --min 1' -- $argv

    set -l timeout_secs (if set -q _flag_timeout; echo $_flag_timeout; else; echo 30; end)

    set -l projects_file "$HOME/Library/Application Support/com.gitbutler.app/projects.json"
    set -l filter $argv[1]

    if not test -f "$projects_file"
        echo "GitButler projects.json not found"
        return 1
    end

    set -l matched 0

    for path in (jq -r '.[].path' "$projects_file")
        set -l name (basename "$path")

        # Skip if filter provided and doesn't match name or path
        if test -n "$filter"; and not string match -q "*$filter*" "$name"; and not string match -q "*$filter*" "$path"
            continue
        end
        if test -d "$path/.git/gitbutler"
            set matched (math $matched + 1)
            # Check status first without colors
            set -l check_output (timeout $timeout_secs but -C "$path" pull --check 2>&1)
            set -l check_status $status

            if test $check_status -eq 124
                echo "$name: "(set_color red)"timed out during check"(set_color normal)
            else if echo "$check_output" | grep -q "Up to date"
                echo "$name: "(set_color green)"up to date"(set_color normal)
            else if echo "$check_output" | grep -q "bad object"
                # Broken refs detected
                if set -q _flag_force
                    echo "$name: "(set_color yellow)"cleaning broken refs..."(set_color normal)
                    # Find all broken refs from git branch warnings
                    for ref in (git -C "$path" branch 2>&1 | grep "warning: ignoring broken ref" | sed 's/.*refs\/heads\//refs\/heads\//')
                        echo "  removing $ref"
                        git -C "$path" update-ref -d "$ref" 2>/dev/null
                    end
                    git -C "$path" fetch --prune origin 2>/dev/null
                    # Retry pull
                    but -C "$path" pull
                    echo ""
                else
                    echo "$name: "(set_color red)"broken refs"(set_color normal)" (use --force to clean)"
                end
            else
                # Has changes or errors - run with full colored output
                echo "$name:"
                timeout $timeout_secs but -C "$path" pull
                if test $status -eq 124
                    echo (set_color red)"  timed out after "$timeout_secs"s"(set_color normal)
                end
                echo ""
            end
        end
    end

    if test -n "$filter"; and test $matched -eq 0
        echo (set_color red)"No projects matching '$filter'"(set_color normal)
        return 1
    end
end
