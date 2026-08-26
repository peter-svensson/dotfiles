function __scw_config_path --description 'Resolve the active scw config file'
    if set -q SCW_CONFIG_PATH; and test -r "$SCW_CONFIG_PATH"
        echo $SCW_CONFIG_PATH
    else
        echo $HOME/.config/scw/config.yaml
    end
end
