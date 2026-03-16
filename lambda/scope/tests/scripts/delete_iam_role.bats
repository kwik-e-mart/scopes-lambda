#!/usr/bin/env bats

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  HELPERS_DIR="$TEST_DIR/helpers"
  LAMBDA_DIR="$(cd "$TEST_DIR/../../.." && pwd)"

  load "$HELPERS_DIR/test_helper.bash"
  load "$HELPERS_DIR/mock_context.bash"

  setup_test_env
  export SERVICE_PATH="$LAMBDA_DIR"

  # Create temp dir for mock binaries
  MOCK_BIN_DIR="$(mktemp -d)"
  export PATH="$MOCK_BIN_DIR:$PATH"
  _TEST_CLEANUP_DIRS=("$MOCK_BIN_DIR")

  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"

  # Unset exported shell functions so file-based mocks on PATH take precedence
  unset -f aws np
}

teardown() {
  teardown_test_env
  for dir in "${_TEST_CLEANUP_DIRS[@]}"; do
    [ -d "$dir" ] && rm -rf "$dir"
  done
}

# Helper: create a mock np script
create_np_mock() {
  local responses_file="$MOCK_BIN_DIR/np_responses"
  local index_file="$MOCK_BIN_DIR/np_index"
  echo "0" > "$index_file"
  > "$responses_file"

  for resp in "$@"; do
    echo "$resp" >> "$responses_file"
  done

  cat > "$MOCK_BIN_DIR/np" << 'MOCK_SCRIPT'
#!/bin/bash
MOCK_DIR="$(dirname "$0")"
INDEX=$(cat "$MOCK_DIR/np_index")
RESPONSE=$(sed -n "$((INDEX + 1))p" "$MOCK_DIR/np_responses")
echo $((INDEX + 1)) > "$MOCK_DIR/np_index"
EXIT_CODE="${RESPONSE%%:*}"
OUTPUT="${RESPONSE#*:}"
if [ "$EXIT_CODE" != "0" ]; then
  echo "$OUTPUT" >&2
  exit "$EXIT_CODE"
fi
echo "$OUTPUT"
exit 0
MOCK_SCRIPT
  chmod +x "$MOCK_BIN_DIR/np"
}

# Helper: create a mock aws script
create_aws_mock() {
  local responses_file="$MOCK_BIN_DIR/aws_responses"
  local index_file="$MOCK_BIN_DIR/aws_index"
  echo "0" > "$index_file"
  > "$responses_file"

  for resp in "$@"; do
    echo "$resp" >> "$responses_file"
  done

  cat > "$MOCK_BIN_DIR/aws" << 'MOCK_SCRIPT'
#!/bin/bash
MOCK_DIR="$(dirname "$0")"
INDEX=$(cat "$MOCK_DIR/aws_index")
RESPONSE=$(sed -n "$((INDEX + 1))p" "$MOCK_DIR/aws_responses")
echo $((INDEX + 1)) > "$MOCK_DIR/aws_index"
EXIT_CODE="${RESPONSE%%:*}"
OUTPUT="${RESPONSE#*:}"
if [ "$EXIT_CODE" != "0" ]; then
  echo "$OUTPUT" >&2
  exit "$EXIT_CODE"
fi
echo "$OUTPUT"
exit 0
MOCK_SCRIPT
  chmod +x "$MOCK_BIN_DIR/aws"
}

@test "scope/scripts/delete_iam_role: skips when not using dedicated role" {
  create_np_mock \
    '0:{"AWS_LAMBDA_USE_DEDICATED_ROLE": "false", "AWS_DEDICATED_ROLE_NAME": "some-role"}'

  run bash "$LAMBDA_DIR/scope/scripts/delete_iam_role"

  assert_success
  assert_output_contains "Not using dedicated role - skipping IAM cleanup"
}

@test "scope/scripts/delete_iam_role: skips when role entity is not scope-level" {
  create_np_mock \
    '0:{"AWS_LAMBDA_USE_DEDICATED_ROLE": "true", "AWS_LAMBDA_DEDICATED_ROLE_ENTITY": "application", "AWS_DEDICATED_ROLE_NAME": "app-role"}'

  run bash "$LAMBDA_DIR/scope/scripts/delete_iam_role"

  assert_success
  assert_output_contains "Role entity is 'application' (not scope-level) - skipping deletion"
}

@test "scope/scripts/delete_iam_role: skips when no role name found in NRN" {
  create_np_mock \
    '0:{"AWS_LAMBDA_USE_DEDICATED_ROLE": "true", "AWS_LAMBDA_DEDICATED_ROLE_ENTITY": "scope", "AWS_DEDICATED_ROLE_NAME": ""}'

  run bash "$LAMBDA_DIR/scope/scripts/delete_iam_role"

  assert_success
  assert_output_contains "No role name found in NRN - skipping IAM cleanup"
}

@test "scope/scripts/delete_iam_role: skips when role does not exist in AWS" {
  create_np_mock \
    '0:{"AWS_LAMBDA_USE_DEDICATED_ROLE": "true", "AWS_LAMBDA_DEDICATED_ROLE_ENTITY": "scope", "AWS_DEDICATED_ROLE_NAME": "lambda-my-scope"}'

  create_aws_mock \
    '1:NoSuchEntity: Role not found'

  run bash "$LAMBDA_DIR/scope/scripts/delete_iam_role"

  assert_success
  assert_output_contains "Role 'lambda-my-scope' does not exist - skipping deletion"
}

@test "scope/scripts/delete_iam_role: deletes role successfully with managed and inline policies" {
  create_np_mock \
    '0:{"AWS_LAMBDA_USE_DEDICATED_ROLE": "true", "AWS_LAMBDA_DEDICATED_ROLE_ENTITY": "scope", "AWS_DEDICATED_ROLE_NAME": "lambda-my-scope"}'

  create_aws_mock \
    '0:{"Role": {"Arn": "arn:aws:iam::123456789012:role/lambda-my-scope", "RoleName": "lambda-my-scope"}}' \
    '0:arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole' \
    '0:' \
    '0:custom-policy-1' \
    '0:' \
    '0:'

  run bash "$LAMBDA_DIR/scope/scripts/delete_iam_role"

  assert_success
  assert_output_contains "Cleaning up IAM role..."
  assert_output_contains "Detaching managed policies from 'lambda-my-scope'..."
  assert_output_contains "Detaching: arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  assert_output_contains "Deleting inline policies from 'lambda-my-scope'..."
  assert_output_contains "Deleting inline policy: custom-policy-1"
  assert_output_contains "Deleting IAM role 'lambda-my-scope'..."
  assert_output_contains "IAM role 'lambda-my-scope' deleted successfully"
  assert_output_contains "IAM cleanup complete"
}

@test "scope/scripts/delete_iam_role: fails when delete-role AWS call fails" {
  create_np_mock \
    '0:{"AWS_LAMBDA_USE_DEDICATED_ROLE": "true", "AWS_LAMBDA_DEDICATED_ROLE_ENTITY": "scope", "AWS_DEDICATED_ROLE_NAME": "lambda-my-scope"}'

  create_aws_mock \
    '0:{"Role": {"Arn": "arn:aws:iam::123456789012:role/lambda-my-scope"}}' \
    '0:' \
    '0:' \
    '1:DeleteConflict: Role still has instance profiles'

  run bash "$LAMBDA_DIR/scope/scripts/delete_iam_role"

  assert_failure
  assert_output_contains "Failed to delete IAM role 'lambda-my-scope'"
  assert_output_contains "Role still has instance profiles attached"
  assert_output_contains "Insufficient IAM permissions"
  assert_output_contains "Remove all instance profiles from the role first"
  assert_output_contains "Verify the agent has iam:DeleteRole permission"
}

@test "scope/scripts/delete_iam_role: logs configuration from NRN" {
  create_np_mock \
    '0:{"AWS_LAMBDA_USE_DEDICATED_ROLE": "true", "AWS_LAMBDA_DEDICATED_ROLE_ENTITY": "scope", "AWS_DEDICATED_ROLE_NAME": "lambda-my-scope"}'

  create_aws_mock \
    '1:NoSuchEntity: not found'

  run bash "$LAMBDA_DIR/scope/scripts/delete_iam_role"

  assert_success
  assert_output_contains "use_dedicated_role=true, role_entity=scope, role_name=lambda-my-scope"
}
