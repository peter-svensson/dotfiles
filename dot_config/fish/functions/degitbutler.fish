function __degitbutler_default_branch --description "Resolve a sane non-gitbutler branch to switch to"
    set -l repo $argv[1]
    # 1. origin/HEAD if it resolves to a real branch
    set -l b (git -C $repo symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | string replace 'origin/' '')
    if test -n "$b"; and test "$b" != HEAD
        echo $b
        return 0
    end
    # 2. conventional local branches
    for cand in main master trunk
        if git -C $repo show-ref --verify --quiet refs/heads/$cand
            echo $cand
            return 0
        end
    end
    # 3. conventional remote branches (git switch DWIM creates a local tracking branch)
    for cand in main master trunk
        if git -C $repo show-ref --verify --quiet refs/remotes/origin/$cand
            echo $cand
            return 0
        end
    end
    # 4. first local branch not in the gitbutler namespace
    for h in (git -C $repo for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)
        string match -q 'gitbutler/*' $h; and continue
        echo $h
        return 0
    end
    return 1
end

function __degitbutler_is_gitbutler --description "True if the common git dir carries gitbutler state"
    set -l repo $argv[1]
    set -l cdir $argv[2]
    test -d "$cdir/gitbutler"; and return 0
    git -C $repo for-each-ref refs/gitbutler 2>/dev/null | grep -q .; and return 0
    git -C $repo for-each-ref refs/heads/gitbutler 2>/dev/null | grep -q .; and return 0
    return 1
end

function degitbutler --description "Walk git repos under a root and strip GitButler state (dry-run by default; --apply to execute)"
    set -l apply 0
    set -l stash 0
    set -l root ''
    for arg in $argv
        switch $arg
            case --apply
                set apply 1
            case --stash
                set stash 1
            case -h --help
                echo "usage: degitbutler [root] [--apply] [--stash]"
                echo "  Walks ROOT (default: cwd) for git repos using GitButler and removes:"
                echo "    - .git/gitbutler/ state dir"
                echo "    - refs/gitbutler/* and refs/heads/gitbutler/* (workspace, target, edit...)"
                echo "  Switches any worktree checked out on a gitbutler/* branch to the default branch."
                echo "  --stash: stash uncommitted changes (incl. untracked) before switching, kept for"
                echo "           later 'git stash pop'. Without it, dirty repos that block the switch are skipped."
                echo "  Finally drops the global [gitbutler] git config section."
                echo "  Dry-run by default. Pass --apply to actually delete."
                return 0
            case '*'
                set root $arg
        end
    end
    test -z "$root"; and set root (pwd)
    if not test -d "$root"
        echo "degitbutler: not a directory: $root" >&2
        return 1
    end
    set root (path resolve $root)

    if test $apply -eq 0
        echo "DRY-RUN (no changes). Pass --apply to execute."
    else
        echo "APPLY MODE — modifying repos."
    end
    echo "root: $root"
    echo ""

    # Discover working trees, skipping vendored / dependency repos.
    set -l gitpaths (fd --hidden --no-ignore --absolute-path \
        --exclude .terraform --exclude .direnv --exclude node_modules --exclude vendor \
        --type d --type f '^\.git$' $root 2>/dev/null)
    set -l repos
    for gp in $gitpaths
        set -l r (path dirname $gp)
        git -C $r rev-parse --git-dir >/dev/null 2>&1; or continue
        set -a repos $r
    end

    if test (count $repos) -eq 0
        echo "No git repositories found under $root"
        return 0
    end

    # ---- Pass 1: switch any worktree off a gitbutler/* branch ----
    echo "== HEAD switches =="
    set -l switched 0
    for r in $repos
        set -l cdir (git -C $r rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
        __degitbutler_is_gitbutler $r $cdir; or continue
        set -l head (git -C $r symbolic-ref --quiet --short HEAD 2>/dev/null)
        string match -q 'gitbutler/*' "$head"; or continue
        set switched 1
        set -l target (__degitbutler_default_branch $r)
        if test -z "$target"
            echo "  [!] $r: on $head but no default branch found — leaving HEAD, branch delete will be skipped" >&2
            continue
        end
        set -l dirty (git -C $r status --porcelain 2>/dev/null)
        if test $apply -eq 0
            set -l note ''
            if test -n "$dirty"
                if test $stash -eq 1
                    set note " (DIRTY — would stash "(count $dirty)" change(s) then switch)"
                else
                    set note " (DIRTY — switch will be skipped; re-run with --stash)"
                end
            end
            echo "  $r: switch HEAD $head -> $target$note"
        else
            if test -n "$dirty"; and test $stash -eq 1
                if git -C $r stash push --include-untracked -m "degitbutler: pre-switch stash" 2>/tmp/degb_stash_err
                    echo "  $r: stashed "(count $dirty)" change(s) (recover with: git -C $r stash pop)"
                else
                    echo "  [!] $r: stash failed, skipping switch:" (cat /tmp/degb_stash_err) >&2
                    continue
                end
            end
            if git -C $r switch $target 2>/tmp/degb_switch_err
                echo "  $r: switched HEAD $head -> $target"
            else
                echo "  [!] $r: failed to switch off $head:" (cat /tmp/degb_switch_err) >&2
            end
        end
    end
    test $switched -eq 0; and echo "  (none)"

    # ---- Pass 2: remove refs / state dir, once per common dir ----
    echo ""
    echo "== Per-repo cleanup =="
    set -l seen
    set -l found 0
    for r in $repos
        set -l cdir (git -C $r rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
        __degitbutler_is_gitbutler $r $cdir; or continue
        contains -- $cdir $seen; and continue
        set -a seen $cdir
        set found 1

        echo ""
        echo "repo: $r"

        # gitbutler/* local branches
        set -l gb_branches (git -C $r for-each-ref --format='%(refname:short)' refs/heads/gitbutler 2>/dev/null)
        if test (count $gb_branches) -gt 0
            echo "  branches ("(count $gb_branches)"): $gb_branches"
            if test $apply -eq 1
                for b in $gb_branches
                    git -C $r branch -D $b >/dev/null 2>/tmp/degb_br_err; or echo "    [!] keep $b:" (cat /tmp/degb_br_err) >&2
                end
            end
        end

        # refs/gitbutler/* virtual refs
        set -l gb_refs (git -C $r for-each-ref --format='%(refname)' refs/gitbutler 2>/dev/null)
        if test (count $gb_refs) -gt 0
            echo "  refs/gitbutler/* ("(count $gb_refs)")"
            if test $apply -eq 1
                for ref in $gb_refs
                    git -C $r update-ref -d $ref >/dev/null 2>&1
                end
            end
        end

        # .git/gitbutler state dir
        if test -d "$cdir/gitbutler"
            echo "  state dir: $cdir/gitbutler"
            test $apply -eq 1; and trash "$cdir/gitbutler"
        end
    end
    test $found -eq 0; and echo "  (no gitbutler repos found)"

    # ---- Global config (shared across all repos) ----
    echo ""
    echo "== Global git config =="
    if git config --global --get-regexp '^gitbutler\.' >/dev/null 2>&1
        echo "  [gitbutler] section in ~/.gitconfig:"
        git config --global --get-regexp '^gitbutler\.' | string replace -r '^' '    '
        if test $apply -eq 1
            git config --global --remove-section gitbutler >/dev/null 2>&1
            echo "  removed."
        end
    else
        echo "  (none)"
    end

    echo ""
    if test $apply -eq 0
        echo "Dry-run complete. Re-run with --apply to perform the removals above."
    else
        echo "Done. GitButler state removed. You can now use plain worktrees."
    end
end
