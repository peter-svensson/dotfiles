function scw-profile --description 'Switch the active Scaleway profile (per-root SCW_CONFIG_PATH)'
    if test -z "$argv[1]"
        echo "Usage: scw-profile <profile>"
        echo "Active: "(set -q SCW_PROFILE; and echo $SCW_PROFILE; or echo '(none)')
        echo "Available:"
        __scw_profile_list | sed 's/^/  /'
        return 1
    end

    if not contains -- $argv[1] (__scw_profile_list)
        echo "Unknown profile '$argv[1]' in "(__scw_config_path)
        echo "Available: "(__scw_profile_list | string join ', ')
        return 1
    end

    set -gx SCW_PROFILE $argv[1]
end

function __scw_config_path --description 'Resolve the active scw config file'
    if set -q SCW_CONFIG_PATH; and test -r "$SCW_CONFIG_PATH"
        echo $SCW_CONFIG_PATH
    else
        echo $HOME/.config/scw/config.yaml
    end
end

function __scw_profile_list --description 'List profiles in the active scw config'
    set -l cfg (__scw_config_path)
    test -r "$cfg"; or return 0
    scw -c "$cfg" config profile list -o json 2>/dev/null \
        | string match -r '"Name"\s*:\s*"([^"]+)"' --groups-only
end

complete -f -c scw-profile -a '(__scw_profile_list)'
