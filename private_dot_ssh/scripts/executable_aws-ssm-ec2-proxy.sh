#!/bin/bash
# AWS SSM + EC2 Instance Connect proxy script for SSH
# Usage: Called automatically by SSH ProxyCommand

set -e

INSTANCE_ID="$1"
INSTANCE_USER="$2"
PORT="${3:-22}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

# Push SSH public key to instance (valid for 60 seconds)
aws ec2-instance-connect send-ssh-public-key \
    --instance-id "$INSTANCE_ID" \
    --instance-os-user "$INSTANCE_USER" \
    --ssh-public-key "file://$HOME/.ssh/id_rsa.pub" \
    --region "$REGION" >/dev/null

# Start SSM session
exec aws ssm start-session \
    --target "$INSTANCE_ID" \
    --document-name AWS-StartSSHSession \
    --parameters "portNumber=$PORT"
