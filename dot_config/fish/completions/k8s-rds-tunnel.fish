# Completions for k8s-rds-tunnel

function __k8s_rds_tunnel_clusters
    if set -q K8S_RDS_CONFIG; and test -f "$K8S_RDS_CONFIG"
        string match -rv '^\s*#|^\s*$' <"$K8S_RDS_CONFIG" | string replace -r '\s.*' ''
    end
end

# Cluster name completion (no file completion)
complete -c k8s-rds-tunnel -f -a '(__k8s_rds_tunnel_clusters)'

# Flags
complete -c k8s-rds-tunnel -s p -l port -d 'Local port (default: 35432)' -r
