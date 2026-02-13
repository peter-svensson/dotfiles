function aws-ssh --description "Start an SSM session to an EC2 instance"
    set -l instance_id $argv[1]

    if test -z "$instance_id"
        echo "Usage: aws-ssh <instance-id>"
        return 1
    end

    aws ssm start-session --target $instance_id
end
