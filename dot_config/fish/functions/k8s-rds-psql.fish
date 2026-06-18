function k8s-rds-psql --description "Connect to RDS PostgreSQL via tunnel using k8s secret credentials"
    argparse 'p/port=!_validate_int --min 1 --max 65535' 'c/context=' 'n/namespace=' 's/secret-name=' 'u/username=' 'from-secret' 'print-local-url' -- $argv
    or return 1

    set -l name $argv[1]

    if test -z "$name"
        echo "Usage: k8s-rds-psql <name> --context <cluster> [--port <local-port>] [--namespace <ns>] [--secret-name <secret>] [--username <user>] [--from-secret]"
        echo ""
        echo "  <name>          Database name, username, and secret name"
        echo "  --context       Kubernetes context (required)"
        echo "  --port          Local port (must match k8s-rds-tunnel, default from rds_config)"
        echo "  --namespace     Kubernetes namespace (default: same as name)"
        echo "  --secret-name   Kubernetes secret name (default: <name>-secrets)"
        echo "  --username        Database username (default: derived from <name>)"
        echo "  --from-secret     Read DB_NAME and DB_USERNAME from the secret instead of deriving from <name>"
        echo "  --print-local-url Print the local port-forwarded connection URL to stdout and exit (no psql)"
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
    set -l username (if set -q _flag_username; echo $_flag_username; else; echo ''; end)

    # Get credentials from k8s secret
    set -l secret_name (if set -q _flag_secret_name; echo $_flag_secret_name; else; echo "$name-secrets"; end)
    echo "Looking up credentials from secret '$secret_name' in namespace '$namespace'..." >&2
    set -l password (kubectl --context $_flag_context -n $namespace get secret $secret_name -o jsonpath='{.data.DB_PASSWORD}' 2>&1)
    if test $status -ne 0
        echo (set_color red)"Failed to get secret: $password"(set_color normal)
        return 1
    end

    set password (echo $password | base64 --decode)

    if set -q _flag_from_secret
        set -l secret_db_name (kubectl --context $_flag_context -n $namespace get secret $secret_name -o jsonpath='{.data.DB_NAME}' 2>/dev/null)
        if test -n "$secret_db_name"
            set db_name (echo $secret_db_name | base64 --decode)
        end
        if test -z "$username"
            set -l secret_username (kubectl --context $_flag_context -n $namespace get secret $secret_name -o jsonpath='{.data.DB_USERNAME}' 2>/dev/null)
            if test -n "$secret_username"
                set username (echo $secret_username | base64 --decode)
            end
        end
    end

    # --username overrides; otherwise default to the derived db_name
    if test -z "$username"
        set username $db_name
    end

    if set -q _flag_print_local_url
        # string escape --style=url leaves '/' raw; '/' is invalid in userinfo, so encode it too.
        set -l enc_user (string escape --style=url -- $username | string replace -a '/' '%2F')
        set -l enc_pass (string escape --style=url -- $password | string replace -a '/' '%2F')
        set -l enc_db (string escape --style=url -- $db_name | string replace -a '/' '%2F')
        echo "postgres://$enc_user:$enc_pass@localhost:$local_port/$enc_db"
        return 0
    end

    echo "Connecting to database '$db_name' as user '$username' on localhost:$local_port..." >&2
    PGPASSWORD=$password psql -h localhost -p $local_port -U $username -d $db_name
end
