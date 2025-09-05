function aws-sso-profile
  set --local _args (string split -- ' ' $AWS_SSO_HELPER_ARGS)
  set -q AWS_SSO_HELPER_ARGS; or set --local _args -L error
  if [ -n "$AWS_PROFILE" ]
      echo "Unable to assume a role while AWS_PROFILE is set"
      return 1
  end

  if [ -z "$argv[1]" ]
      echo "Usage: aws-sso-profile <profile>"
      return 1
  end

  eval $(/opt/homebrew/bin/aws-sso $_args eval -p $argv[1])
  if [ "$AWS_SSO_PROFILE" != "$1" ]
      return 1
  end
end

function __aws_sso_profile_complete
  set --local _args (string split -- ' ' $AWS_SSO_HELPER_ARGS)
  set -q AWS_SSO_HELPER_ARGS; or set --local _args -L error
  set -l cur (commandline -t)

  set -l cmd "/opt/homebrew/bin/aws-sso list $_args --csv -P Profile=$cur Profile"
  for completion in (eval $cmd)
    printf "%s\n" $completion
  end
end
complete -f -c aws-sso-profile -f -a '(__aws_sso_profile_complete)'
