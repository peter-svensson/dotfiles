function scw-profile --description 'Switch the active Scaleway profile (per-root SCW_CONFIG_PATH)'
    if test -z "$argv[1]"
        echo "Usage: scw-profile <profile>"
        echo "Active: "(set -q SCW_PROFILE; and echo $SCW_PROFILE; or echo '(none)')
        echo "Config: "(__scw_config_path)
        echo "Available:"
        __scw_profile_complete | string replace \t '  ->  ' | sed 's/^/  /'
        return 1
    end

    if not contains -- $argv[1] (__scw_profile_list)
        echo "Unknown profile '$argv[1]' in "(__scw_config_path)
        echo "Available: "(__scw_profile_list | string join ', ')
        return 1
    end

    set -gx SCW_PROFILE $argv[1]
    echo "SCW_PROFILE=$argv[1]"
end

function __scw_config_path --description 'Resolve the active scw config file'
    if set -q SCW_CONFIG_PATH; and test -r "$SCW_CONFIG_PATH"
        echo $SCW_CONFIG_PATH
    else
        echo $HOME/.config/scw/config.yaml
    end
end

# Parse profile names straight out of the YAML rather than shelling out to
# `scw config profile list`. That command needs the whole config to load, so a
# single unrenderable secret makes it exit non-zero and completion goes silently
# empty. Profiles are the two-space-indented keys under `profiles:`.
function __scw_profile_list --description 'List profiles in the active scw config'
    set -l cfg (__scw_config_path)
    test -r "$cfg"; or return 0
    sed -n '/^profiles:/,$p' "$cfg" \
        | string match -r '^  ([a-zA-Z0-9_-]+):$' --groups-only
end

# Completion candidates as `name\tproject-id`, so the project each profile
# points at is visible at the prompt.
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

complete -f -c scw-profile -a '(__scw_profile_complete)'
