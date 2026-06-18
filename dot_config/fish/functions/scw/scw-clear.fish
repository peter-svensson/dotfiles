function scw-clear --description 'Clear the per-shell Scaleway profile override (revert to .envrc default)'
    if not set -q SCW_PROFILE
        echo "SCW_PROFILE is not set"
        return 1
    end
    set --erase SCW_PROFILE
end
