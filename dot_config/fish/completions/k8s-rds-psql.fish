# Completions for k8s-rds-psql

function __k8s_rds_psql_contexts
    kubectl config get-contexts -o name 2>/dev/null
end

function __k8s_rds_psql_namespaces
    set -l ctx (commandline -opc | string match -r -- '--context\s+(\S+)' | tail -1)
    if test -n "$ctx"
        kubectl --context $ctx get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | string split ' '
    end
end

# No file completion by default
complete -c k8s-rds-psql -f

# Flags
complete -c k8s-rds-psql -s c -l context -d 'Kubernetes context (required)' -r -a '(__k8s_rds_psql_contexts)'
complete -c k8s-rds-psql -s p -l port -d 'Local port (must match k8s-rds-tunnel)' -r
complete -c k8s-rds-psql -s n -l namespace -d 'Kubernetes namespace (default: same as name)' -r -a '(__k8s_rds_psql_namespaces)'
complete -c k8s-rds-psql -s s -l secret-name -d 'Kubernetes secret name (default: <name>-secrets)' -r
