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

@test "scope/scripts/store_scope_metadata: stores function name in metadata" {
  export LAMBDA_FUNCTION_NAME="my-namespace-my-app-my-scope-scope-123"

  create_np_mock '0:{"status": "ok"}'

  run bash "$LAMBDA_DIR/scope/scripts/store_scope_metadata"

  assert_success
  assert_output_contains "function_name=my-namespace-my-app-my-scope-scope-123"
  assert_output_contains "Metadata stored successfully"
}

@test "scope/scripts/store_scope_metadata: stores function ARN in metadata" {
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_FUNCTION_ARN="arn:aws:lambda:us-east-1:123456789012:function:my-function"

  create_np_mock '0:{"status": "ok"}'

  run bash "$LAMBDA_DIR/scope/scripts/store_scope_metadata"

  assert_success
  assert_output_contains "function_arn=arn:aws:lambda:us-east-1:123456789012:function:my-function"
}

@test "scope/scripts/store_scope_metadata: stores role ARN and role name" {
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_ROLE_ARN="arn:aws:iam::123456789012:role/lambda-role"
  export LAMBDA_ROLE_NAME="lambda-role"

  create_np_mock '0:{"status": "ok"}'

  run bash "$LAMBDA_DIR/scope/scripts/store_scope_metadata"

  assert_success
  assert_output_contains "role_arn=arn:aws:iam::123456789012:role/lambda-role"
  assert_output_contains "role_name=lambda-role"
}

@test "scope/scripts/store_scope_metadata: stores default main alias" {
  export LAMBDA_FUNCTION_NAME="my-function"

  create_np_mock '0:{"status": "ok"}'

  run bash "$LAMBDA_DIR/scope/scripts/store_scope_metadata"

  assert_success
  assert_output_contains "main_alias=main"
}

@test "scope/scripts/store_scope_metadata: stores custom main alias from environment" {
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_MAIN_ALIAS_NAME="production"

  create_np_mock '0:{"status": "ok"}'

  run bash "$LAMBDA_DIR/scope/scripts/store_scope_metadata"

  assert_success
  assert_output_contains "main_alias=production"
}

@test "scope/scripts/store_scope_metadata: stores scope domain when set" {
  export LAMBDA_FUNCTION_NAME="my-function"
  export SCOPE_DOMAIN="api.example.com"

  create_np_mock '0:{"status": "ok"}'

  run bash "$LAMBDA_DIR/scope/scripts/store_scope_metadata"

  assert_success
  assert_output_contains "scope_domain=api.example.com"
}

@test "scope/scripts/store_scope_metadata: fails when np nrn write fails" {
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_FUNCTION_ARN="arn:aws:lambda:us-east-1:123456789012:function:my-function"

  create_np_mock '1:API error: connection refused'

  run bash "$LAMBDA_DIR/scope/scripts/store_scope_metadata"

  assert_failure
  assert_output_contains "Failed to write scope metadata to NRN"
  assert_output_contains "nullplatform API is unavailable"
  assert_output_contains "Malformed metadata JSON"
  assert_output_contains "Check nullplatform API connectivity"
  assert_output_contains "Verify the NRN path is correct"
}

@test "scope/scripts/store_scope_metadata: outputs full success flow log messages" {
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_FUNCTION_ARN="arn:aws:lambda:us-east-1:123456789012:function:my-function"
  export LAMBDA_ROLE_ARN="arn:aws:iam::123456789012:role/lambda-role"
  export LAMBDA_ROLE_NAME="lambda-role"
  export SCOPE_DOMAIN="api.example.com"

  create_np_mock '0:{"status": "ok"}'

  run bash "$LAMBDA_DIR/scope/scripts/store_scope_metadata"

  assert_success
  assert_output_contains "Storing scope metadata in NRN..."
  assert_output_contains "Writing metadata to NRN (scope_nrn=$SCOPE_NRN, namespace=aws)..."
  assert_output_contains "Metadata stored successfully"
  assert_line "✨ Scope metadata saved to NRN"
}
