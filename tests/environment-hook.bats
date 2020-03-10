#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# export SSH_AGENT_STUB_DEBUG=/dev/tty
# export SSH_ADD_STUB_DEBUG=/dev/tty
# export VAULT_STUB_DEBUG=/dev/tty
# export GIT_STUB_DEBUG=/dev/tty

function setup() {
  [ -f ./custom-defaults ] && rm ./custom-defaults
  true
}

function teardown() {
  [ -f ./custom-defaults ] && rm ./custom-defaults
  true
}

@test "Load default env file from parameterstore" {
  export AWS_STUB_DEBUG=/dev/tty
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH=/base_path
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV=true
  export BUILDKITE_PIPELINE_SLUG=testpipe
  export TESTDATA=`echo MY_SECRET=fooblah`
  export AWS_DEFAULT_REGION=eu-boohar-99

  stub python3 \
    "../lib/environment.py : echo testpipe"

  stub aws \
    "ssm describe-parameters --parameter-filters 'Key=Path,Option=Recursive,Values=/base_path/global' 'Key=Type,Values=SecureString' --query 'Parameters[*][Name]' --region=eu-boohar-99  --output text : echo -e '/base_path/global/env/envvar1'" \
    "ssm get-parameter --name /base_path/global/env/envvar1 --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo fooblah" \
    "ssm describe-parameters --parameter-filters Key=Path,Option=Recursive,Values=/base_path/testpipe 'Key=Type,Values=SecureString' --query 'Parameters[*][Name]' --region=eu-boohar-99  --output text : echo /base_path/testpipe/ssh/key1" \
    "ssm get-parameter --name /base_path/testpipe/ssh/key1 --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo fookey"

  stub ssh-agent \
    "-s : echo export SSH_AGENT_PID=26346"
  stub ssh-add \
    '- : echo added ssh key'
  run bash -c "$PWD/hooks/environment && $PWD/hooks/pre-exit"

  assert_output --partial "envvar1=fooblah"
  assert_success

  unstub aws
  unstub ssh-agent
  unstub ssh-add
  unstub python3

  unset TESTDATA
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH
  unset BUILDKITE_PIPELINE_SLUG
  unset AWS_DEFAULT_REGION
}

@test "Load secrets using a non-std key" {
  export AWS_STUB_DEBUG=/dev/tty
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH=/base_path
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV=true
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_KEY=BUILDKITE_REPO
  export TESTDATA=`echo MY_SECRET=fooblah`
  export AWS_DEFAULT_REGION=eu-boohar-99
  export BUILDKITE_REPO=zzzzzz

  stub aws \
    "ssm describe-parameters --parameter-filters 'Key=Path,Option=Recursive,Values=/base_path/global' 'Key=Type,Values=SecureString' --query 'Parameters[*][Name]' --region=eu-boohar-99  --output text : echo -e '/base_path/global/env/envvar1'" \
    "ssm get-parameter --name /base_path/global/env/envvar1 --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo fooblah" \
    "ssm describe-parameters --parameter-filters Key=Path,Option=Recursive,Values=/base_path/zzzzzz 'Key=Type,Values=SecureString' --query 'Parameters[*][Name]' --region=eu-boohar-99  --output text : echo /base_path/zzzzzz/env/key1" \
    "ssm get-parameter --name /base_path/zzzzzz/env/key1 --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo fookey"

  run bash -c "$PWD/hooks/environment && $PWD/hooks/pre-exit"

  assert_output --partial "envvar1=fooblah"
  assert_output --partial "key1=fookey"
  assert_success

  unstub aws

  unset TESTDATA
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_KEY
  unset AWS_DEFAULT_REGION
  unset BUILDKITE_REPO
}

@test "Load customised default slug" {
  # export AWS_STUB_DEBUG=/dev/tty
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH=/base_path
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV=true
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DEFAULT_KEY=testpipe
  export TESTDATA=`echo MY_SECRET=fooblah`
  export AWS_DEFAULT_REGION=eu-boohar-99

  stub aws \
    "ssm describe-parameters --parameter-filters 'Key=Path,Option=Recursive,Values=/base_path/testpipe' 'Key=Type,Values=SecureString' --query 'Parameters[*][Name]' --region=eu-boohar-99  --output text : echo -e '/base_path/testpipe/env/envvar1'" \
    "ssm get-parameter --name /base_path/testpipe/env/envvar1 --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo fooblah"

  run bash -c "$PWD/hooks/environment && $PWD/hooks/pre-exit"

  assert_success
  assert_output --partial "envvar1=fooblah"

  unstub aws

  unset TESTDATA
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DEFAULT_KEY
  unset AWS_DEFAULT_REGION
}

@test "Load customised default slug via custom-defaults file" {
  cat <<EOF >./custom-defaults
BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH=/base_path
BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DEFAULT_KEY=testpipe
BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV=true
AWS_DEFAULT_REGION=eu-boohar-99
EOF

  export TESTDATA=`echo MY_SECRET=fooblah`

  stub aws \
    "ssm describe-parameters --parameter-filters 'Key=Path,Option=Recursive,Values=/base_path/testpipe' 'Key=Type,Values=SecureString' --query 'Parameters[*][Name]' --region=eu-boohar-99  --output text : echo -e '/base_path/testpipe/env/envvar1'" \
    "ssm get-parameter --name /base_path/testpipe/env/envvar1 --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo fooblah"

  run bash -c "$PWD/hooks/environment && $PWD/hooks/pre-exit && rm ./custom-defaults"

  assert_success
  assert_output --partial "envvar1=fooblah"

  unstub aws

  unset TESTDATA
}

@test "Handle awkard env var values" {
  skip "doesnot handle single quote yet"
  # This is made difficult by bats
  # export AWS_STUB_DEBUG=/dev/tty
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH=/base_path
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV=true
  export AWS_DEFAULT_REGION=eu-boohar-99

  env_vars=(
    "/base_path/global/env/has_a_space_in_the_value"
    "/base_path/global/env/has_a_double_quote_in_the_value"
    "/base_path/global/env/has_a_single_quote_in_the_value"
  )
  stub aws \
    "ssm describe-parameters --parameter-filters 'Key=Path,Option=Recursive,Values=/base_path/global' 'Key=Type,Values=SecureString' --query 'Parameters[*][Name]' --region=eu-boohar-99  --output text : echo -e \"${env_vars[*]}\"" \
    "ssm get-parameter --name ${env_vars[0]} --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo -e 'foo blah'" \
    "ssm get-parameter --name ${env_vars[1]} --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo -e 'ab\"cd'" \
    "ssm get-parameter --name ${env_vars[2]} --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo -e \"kl\'zx\""

  run bash -c "$PWD/hooks/environment && $PWD/hooks/pre-exit"

  assert_success
  assert_output --partial "$(basename ${env_vars[0]})=foo blah"
  assert_output --partial "$(basename ${env_vars[1]})=ab\"cd"
  assert_output --partial "$(basename ${env_vars[2]})=kl'zx"

  unstub aws

  unset TESTDATA
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH
  unset BUILDKITE_PIPELINE_SLUG
  unset AWS_DEFAULT_REGION
}

@test "Load customised default slug - is a URL" {
  export AWS_STUB_DEBUG=/dev/tty
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH=/base_path
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV=true
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_KEY='https://host.io/path'
  export TESTDATA=`echo MY_SECRET=fooblah`
  export AWS_DEFAULT_REGION=eu-boohar-99

  stub aws \
    "ssm describe-parameters --parameter-filters 'Key=Path,Option=Recursive,Values=/base_path/host.io/path' 'Key=Type,Values=SecureString' --query 'Parameters[*][Name]' --region=eu-boohar-99  --output text : echo -e '/base_path/host.io:7999/path/env/envvar1'" \
    "ssm get-parameter --name /base_path/host.io/path/env/envvar1 --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo fooblah"

  run bash -c "$PWD/hooks/environment && $PWD/hooks/pre-exit"

  assert_success
  assert_output --partial "envvar1=fooblah"

  unstub aws

  unset TESTDATA
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DEFAULT_KEY
  unset AWS_DEFAULT_REGION
}

@test "Load customised default slug - is a URL with args" {
  export AWS_STUB_DEBUG=/dev/tty
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH=/base_path
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV=true
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_KEY='https://user:password@host.io:7999/path?arg1=val1'
  export TESTDATA=`echo MY_SECRET=fooblah`
  export AWS_DEFAULT_REGION=eu-boohar-99

  stub python3 \
    "../lib/environment.py : echo host.io_7999_path"

  stub aws \
    "ssm describe-parameters --parameter-filters 'Key=Path,Option=Recursive,Values=/base_path/host.io_7999_path' 'Key=Type,Values=SecureString' --query 'Parameters[*][Name]' --region=eu-boohar-99  --output text : echo -e '/base_path/host.io_7999_path/env/envvar1'" \
    "ssm get-parameter --name /base_path/host.io_7999_path/env/envvar1 --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo fooblah"

  run bash -c "$PWD/hooks/environment && $PWD/hooks/pre-exit"

  assert_success
  assert_output --partial "envvar1=fooblah"

  unstub aws
  unstub python3

  unset TESTDATA
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DEFAULT_KEY
  unset AWS_DEFAULT_REGION
}

@test "Load customised default slug - is a URL - with default port" {
  export PYTHON3_STUB_DEBUG=/dev/tty
  export AWS_STUB_DEBUG=/dev/tty
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH=/base_path
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV=true
  export BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_KEY='https://user:password@host.io/path'
  export TESTDATA=`echo MY_SECRET=fooblah`
  export AWS_DEFAULT_REGION=eu-boohar-99

  stub python3 \
    "../lib/environment.py : echo host.io_path"

  stub aws \
    "ssm describe-parameters --parameter-filters 'Key=Path,Option=Recursive,Values=/base_path/host.io_path' 'Key=Type,Values=SecureString' --query 'Parameters[*][Name]' --region=eu-boohar-99  --output text : echo -e '/base_path/host.io_path/env/envvar1'" \
    "ssm get-parameter --name /base_path/host.io_path/env/envvar1 --with-decryption --query 'Parameter.[Value]' --region=eu-boohar-99  --output text : echo fooblah"

  run bash -c "$PWD/hooks/environment && $PWD/hooks/pre-exit"

  assert_success
  assert_output --partial "envvar1=fooblah"

  unstub aws
  unstub python3

  unset TESTDATA
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DUMP_ENV
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_PATH
  unset BUILDKITE_PLUGIN_AWS_PARAMSTORE_SECRETS_DEFAULT_KEY
  unset AWS_DEFAULT_REGION
}
# TODO: test envvar clobber

@test "Load default environment file from parameterstore" {
  skip
}

@test "Load default env and environments files from parameterstore" {
  skip
}

#-------
# Project scope
@test "Load project env file from parameterstore" {
  skip
}

@test "Load project environment file from parameterstore" {
  skip
}

@test "Load project env and environments files from parameterstore" {
  skip
}

#-------
# Combinations of scopes
@test "Load default and project env files from parameterstore" {
  skip
}

@test "Load default and project environment files from parameterstore" {
  skip
}

#-------
# All scopes and env, environment files
@test "Load env and environments files for project and default from parameterstore" {
  skip
}

#-------
# Git Credentials
@test "Load default git-credentials from parameterstore into GIT_CONFIG_PARAMETERS" {
  skip
}

@test "Load pipeline git-credentials from parameterstore into GIT_CONFIG_PARAMETERS" {
  skip
}

#-------
# ssh-keys
@test "Load default ssh-key from parameterstore into ssh-agent" {
  skip
}

@test "Load project ssh-key from parameterstore into ssh-agent" {
  skip
}

@test "Load default and project ssh-keys from parameterstore into ssh-agent" {
  skip
}

@test "Load default ssh-key and env from parameterstore" {
  skip
}

@test "Load project ssh-key and env from parameterstore" {
  skip
}

@test "Load default ssh-key, env and git-credentials from parameterstore into ssh-agent" {
  skip
}

@test "Load project ssh-key, env and git-credentials from parameterstore into ssh-agent" {
  skip
}

@test "Dump env secrets" {
  skip
}
