function k8s-rds-psql --description "Connect to RDS PostgreSQL via tunnel using k8s secret credentials"
    argparse 'p/port=!_validate_int --min 1 --max 65535' 'c/context=' 'n/namespace=' -- $argv
    or return 1

    set -l name $argv[1]

    if test -z "$name"
        echo "Usage: k8s-rds-psql <name> --context <cluster> [--port <local-port>] [--namespace <ns>]"
        echo ""
        echo "  <name>        Database name, username, and secret name"
        echo "  --context     Kubernetes context (required)"
        echo "  --port        Local port (must match k8s-rds-tunnel, default from rds_config)"
        echo "  --namespace   Kubernetes namespace (default: same as name)"
        return 1
    end

    if not set -q _flag_context
        echo (set_color red)"--context is required"(set_color normal)
        echo "Usage: k8s-rds-psql <name> --context <cluster>"
        return 1
    end

    set -l local_port (if set -q _flag_port; echo $_flag_port; else; echo 35432; end)
    set -l namespace (if set -q _flag_namespace; echo $_flag_namespace; else; echo $name; end)
    set -l db_name (string replace -a '-' '_' $name)

    # Get password from k8s secret
    set -l secret_name "$name-secrets"
    echo "Looking up password from secret '$secret_name' in namespace '$namespace'..."
    set -l password (kubectl --context $_flag_context -n $namespace get secret $secret_name -o jsonpath='{.data.DB_PASSWORD}' 2>&1)
    if test $status -ne 0
        echo (set_color red)"Failed to get secret: $password"(set_color normal)
        return 1
    end

    set password (echo $password | base64 --decode)

    echo "Connecting to database '$db_name' as user '$db_name' on localhost:$local_port..."
    PGPASSWORD=$password psql -h localhost -p $local_port -U $db_name -d $db_name
end
