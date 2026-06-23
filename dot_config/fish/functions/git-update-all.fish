function git-update-all --description "Fetch + checkout default branch + rebase onto origin for every git repo under a root (skips worktrees)"
    argparse stash -- $argv; or return 1
    set -l root $argv[1]
    test -z "$root"; and set root (pwd)

    if not test -d "$root"
        echo (set_color red)"not a directory: $root"(set_color normal)
        return 1
    end

    for dir in $root/*/
        set -l name (basename "$dir")
        set -l gitpath "$dir.git"

        # Not a repo
        test -e "$gitpath"; or continue

        # Linked worktree has .git as a FILE (gitdir pointer); real repo has .git DIR. Skip worktrees.
        if not test -d "$gitpath"
            echo "$name: "(set_color yellow)"skip (worktree)"(set_color normal)
            continue
        end

        # No origin remote: local-only repo, nothing to fetch. Inform and skip.
        if not git -C "$dir" remote get-url origin >/dev/null 2>&1
            echo "$name: "(set_color yellow)"skip (no remote)"(set_color normal)
            continue
        end

        # Dirty tree would be clobbered by rebase/checkout. Stash (incl. untracked) with --stash, else skip.
        set -l stashed 0
        set -l dirty (git -C "$dir" status --porcelain)
        if test -n "$dirty"
            if not set -q _flag_stash
                echo "$name: "(set_color yellow)"skip (uncommitted changes)"(set_color normal)
                continue
            end
            if git -C "$dir" stash push --include-untracked -m "git-update-all auto" >/dev/null 2>&1
                set stashed 1
            else
                echo "$name: "(set_color red)"stash failed"(set_color normal)
                continue
            end
        end

        if not git -C "$dir" fetch --prune origin 2>/dev/null
            echo "$name: "(set_color red)"fetch failed"(set_color normal)
            test $stashed -eq 1; and git -C "$dir" stash pop >/dev/null 2>&1
            continue
        end

        # Resolve remote default branch (origin/HEAD), fall back to main
        set -l branch (git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | string replace 'origin/' '')
        test -z "$branch"; and set branch main

        if not git -C "$dir" checkout "$branch" 2>/dev/null
            echo "$name: "(set_color red)"checkout $branch failed"(set_color normal)
            test $stashed -eq 1; and git -C "$dir" stash pop >/dev/null 2>&1
            continue
        end

        if git -C "$dir" rebase "origin/$branch" 2>/dev/null
            echo "$name: "(set_color green)"$branch up to date with origin/$branch"(set_color normal)
        else
            git -C "$dir" rebase --abort 2>/dev/null
            echo "$name: "(set_color red)"rebase failed (aborted)"(set_color normal)
        end

        # Restore stashed work onto the updated branch
        if test $stashed -eq 1
            if git -C "$dir" stash pop >/dev/null 2>&1
                echo "$name: "(set_color cyan)"stash restored"(set_color normal)
            else
                # Pop conflicted — discard the half-applied merge, keep stash intact for manual recovery
                git -C "$dir" reset --hard HEAD >/dev/null 2>&1
                echo "$name: "(set_color red)"stash pop conflicted — kept in stash list (git stash list)"(set_color normal)
            end
        end
    end
end
