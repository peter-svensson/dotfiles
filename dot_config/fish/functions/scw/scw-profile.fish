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
