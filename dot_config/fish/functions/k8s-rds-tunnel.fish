function k8s-rds-tunnel --description "Port forward to RDS via SSM through a k8s node"
    argparse 'p/port=!_validate_int --min 1 --max 65535' -- $argv
    or return 1

    set -l local_port (if set -q _flag_port; echo $_flag_port; else; echo 35432; end)
    set -l cluster $argv[1]

    # Read config file
    if not set -q K8S_RDS_CONFIG
        echo (set_color red)"K8S_RDS_CONFIG is not set"(set_color normal)
        return 1
    end

    if not test -f "$K8S_RDS_CONFIG"
        echo (set_color red)"Config file not found: $K8S_RDS_CONFIG"(set_color normal)
        return 1
    end

    # Parse available clusters from config
    set -l clusters
    for line in (string match -rv '^\s*#|^\s*$' < "$K8S_RDS_CONFIG")
        set -l fields (string split ' ' -- (string trim $line))
        set -a clusters $fields[1]
    end

    if test -z "$cluster"
        echo "Usage: k8s-rds-tunnel <cluster-name> [--port <local-port>]"
        echo ""
        echo "Available clusters:"
        for c in $clusters
            echo "  $c"
        end
        return 1
    end

    # Look up cluster in config
    set -l rds_host
    set -l region
    set -l remote_port
    for line in (string match -rv '^\s*#|^\s*$' < "$K8S_RDS_CONFIG")
        set -l fields (string split ' ' -- (string trim $line))
        if test "$fields[1]" = "$cluster"
            set rds_host $fields[2]
            set region $fields[3]
            set remote_port (if test -n "$fields[4]"; echo $fields[4]; else; echo 5432; end)
            break
        end
    end

    if test -z "$rds_host"
        echo (set_color red)"Unknown cluster: $cluster"(set_color normal)
        echo ""
        echo "Available clusters:"
        for c in $clusters
            echo "  $c"
        end
        return 1
    end

    # Get a node instance ID from the cluster
    echo "Getting node from cluster $cluster..."
    set -l instance_id (kubectl --context $cluster get nodes -o jsonpath='{.items[0].spec.providerID}' 2>&1)
    if test $status -ne 0
        echo (set_color red)"Failed to get node from cluster: $instance_id"(set_color normal)
        return 1
    end

    # Extract instance ID from provider ID (format: aws:///az/i-xxx)
    set instance_id (string replace -r '.*/' '' $instance_id)

    if test -z "$instance_id"
        echo (set_color red)"No nodes found in cluster $cluster"(set_color normal)
        return 1
    end

    # Check if local port is already in use
    if lsof -i :$local_port -sTCP:LISTEN >/dev/null 2>&1
        echo (set_color red)"Port $local_port is already in use"(set_color normal)
        echo "Use --port to specify a different local port"
        return 1
    end

    echo "Using node: $instance_id"
    echo "Forwarding localhost:$local_port → $rds_host:$remote_port via $instance_id"
    echo ""

    aws ssm start-session \
        --region $region \
        --target $instance_id \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters "host=$rds_host,portNumber=$remote_port,localPortNumber=$local_port"
end
