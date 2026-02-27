function aws-ssh --description "Start an SSM session to an EC2 instance"
    set -l instance_id $argv[1]

    if test -z "$instance_id"
        echo "Usage: aws-ssh <instance-id> [--no-root]"
        return 1
    end

    if contains -- --no-root $argv
        aws ssm start-session --target $instance_id
    else
        aws ssm start-session --target $instance_id --document-name AWS-StartInteractiveCommand --parameters command="sudo su -"
    end
end
