# Completion candidates as `name\tproject-id`, so the project each profile
# points at is visible at the prompt. Registered in conf.d/scw.fish.
# Own file so fish can autoload it by name when completion fires.
function __scw_profile_complete --description 'Profile names with their default project id'
    set -l cfg (__scw_config_path)
    test -r "$cfg"; or return 0
    set -l current
    for line in (sed -n '/^profiles:/,$p' "$cfg")
        set -l name (string match -r '^  ([a-zA-Z0-9_-]+):$' --groups-only -- $line)
        test -n "$name"; and set current $name; and continue
        set -l proj (string match -r '^    default_project_id:\s*(\S+)' --groups-only -- $line)
        test -n "$proj" -a -n "$current"; and printf '%s\t%s\n' $current $proj
    end
end
