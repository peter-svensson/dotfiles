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
