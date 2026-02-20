#!/usr/bin/env bats

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  HELPERS_DIR="$TEST_DIR/helpers"
  LAMBDA_DIR="$(cd "$TEST_DIR/../../.." && pwd)"

  load "$HELPERS_DIR/test_helper.bash"
  load "$HELPERS_DIR/mock_context.bash"

  setup_test_env
  export SERVICE_PATH="$LAMBDA_DIR"

  SCRIPT="$LAMBDA_DIR/deployment/scripts/store_nrn_metadata"

  # Create temp dir for file-based mocks
  MOCK_BIN_DIR="$(mktemp -d)"
  export PATH="$MOCK_BIN_DIR:$PATH"

  # Unset exported functions so PATH-based mocks take precedence
  unset -f aws np
}

teardown() {
  teardown_test_env
  rm -rf "$MOCK_BIN_DIR"
}

# Helper: create a mock np script
create_np_mock() {
  local response="$1"
  local exit_code="${2:-0}"
  echo "$response" > "$MOCK_BIN_DIR/np_response.txt"
  cat > "$MOCK_BIN_DIR/np" <<'OUTERSCRIPT'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cat "$SCRIPT_DIR/np_response.txt"
OUTERSCRIPT
  echo "exit $exit_code" >> "$MOCK_BIN_DIR/np"
  chmod +x "$MOCK_BIN_DIR/np"
}

# Helper: create a mock np that fails
create_np_error_mock() {
  local error_message="${1:-An error occurred}"
  echo "$error_message" > "$MOCK_BIN_DIR/np_error.txt"
  cat > "$MOCK_BIN_DIR/np" <<'OUTERSCRIPT'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cat "$SCRIPT_DIR/np_error.txt" >&2
exit 1
OUTERSCRIPT
  chmod +x "$MOCK_BIN_DIR/np"
}

@test "deployment/scripts/store_nrn_metadata: fails when SCOPE_NRN is not set" {
  unset SCOPE_NRN
  export LAMBDA_FUNCTION_NAME="my-function"

  run bash "$SCRIPT"

  assert_failure
  assert_line "❌ SCOPE_NRN is required"
  assert_output_contains "💡 Possible causes:"
  assert_output_contains "Scope context not available in the environment"
  assert_output_contains "NRN not passed from the deployment pipeline"
  assert_output_contains "🔧 How to fix:"
  assert_output_contains "Verify SCOPE_NRN is exported before this script runs"
  assert_output_contains "Check the deployment agent configuration"
}

@test "deployment/scripts/store_nrn_metadata: fails when LAMBDA_FUNCTION_NAME is not set" {
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
  unset LAMBDA_FUNCTION_NAME

  run bash "$SCRIPT"

  assert_failure
  assert_line "❌ LAMBDA_FUNCTION_NAME is required"
  assert_output_contains "💡 Possible causes:"
  assert_output_contains "Environment variable not set by the deployment pipeline"
  assert_output_contains "Scope context missing Lambda function configuration"
  assert_output_contains "🔧 How to fix:"
  assert_output_contains "Ensure the scope has a valid Lambda function configured"
  assert_output_contains "Check that LAMBDA_FUNCTION_NAME is exported before this script runs"
}

@test "deployment/scripts/store_nrn_metadata: stores minimal metadata with only function name" {
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
  export LAMBDA_FUNCTION_NAME="my-function"

  create_np_mock '{"ok": true}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "📝 Storing deployment metadata in NRN..."
  assert_output_contains "scope_nrn=organization=1:account=2:namespace=3:application=4:scope=5"
  assert_output_contains "function_name=my-function"
  assert_output_contains "Writing metadata to NRN=organization=1:account=2:namespace=3:application=4:scope=5..."
  assert_output_contains "Metadata stored successfully"
  assert_output_contains "✨ NRN metadata saved for scope=organization=1:account=2:namespace=3:application=4:scope=5 function=my-function"
}

@test "deployment/scripts/store_nrn_metadata: includes function ARN when set" {
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_FUNCTION_ARN="arn:aws:lambda:us-east-1:123456789012:function:my-function"

  create_np_mock '{"ok": true}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "function_arn=arn:aws:lambda:us-east-1:123456789012:function:my-function"
}

@test "deployment/scripts/store_nrn_metadata: includes current version when set" {
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_FUNCTION_VERSION="5"

  create_np_mock '{"ok": true}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "current_version=5"
}

@test "deployment/scripts/store_nrn_metadata: includes new version when set" {
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_NEW_VERSION="6"

  create_np_mock '{"ok": true}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "new_version=6"
}

@test "deployment/scripts/store_nrn_metadata: includes alias name when set" {
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_ALIAS_NAME="main"

  create_np_mock '{"ok": true}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "main_alias=main"
}

@test "deployment/scripts/store_nrn_metadata: includes all optional fields when set" {
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_FUNCTION_ARN="arn:aws:lambda:us-east-1:123456789012:function:my-function"
  export LAMBDA_FUNCTION_VERSION="5"
  export LAMBDA_NEW_VERSION="6"
  export LAMBDA_ALIAS_NAME="main"
  export LAMBDA_ROLE_ARN="arn:aws:iam::123456789012:role/my-role"
  export API_GATEWAY_ID="abc123"
  export SCOPE_DOMAIN="api.example.com"

  create_np_mock '{"ok": true}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "function_name=my-function"
  assert_output_contains "function_arn=arn:aws:lambda:us-east-1:123456789012:function:my-function"
  assert_output_contains "current_version=5"
  assert_output_contains "new_version=6"
  assert_output_contains "main_alias=main"
  assert_output_contains "role_arn=arn:aws:iam::123456789012:role/my-role"
  assert_output_contains "api_gateway_id=abc123"
  assert_output_contains "scope_domain=api.example.com"
}

@test "deployment/scripts/store_nrn_metadata: logs NRN write target in output" {
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
  export LAMBDA_FUNCTION_NAME="my-function"

  create_np_mock '{"ok": true}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "Writing metadata to NRN=organization=1:account=2:namespace=3:application=4:scope=5..."
}

@test "deployment/scripts/store_nrn_metadata: fails when np nrn write fails" {
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
  export LAMBDA_FUNCTION_NAME="my-function"

  create_np_error_mock "Connection refused"

  run bash "$SCRIPT"

  assert_failure
  assert_output_contains "❌ Failed to write NRN metadata to scope=organization=1:account=2:namespace=3:application=4:scope=5"
  assert_output_contains "💡 Possible causes:"
  assert_output_contains "NRN service is unreachable"
  assert_output_contains "Invalid metadata JSON payload"
  assert_output_contains "Insufficient permissions to write to NRN"
  assert_output_contains "🔧 How to fix:"
  assert_output_contains "Check NRN service connectivity"
  assert_output_contains "Verify the metadata JSON is valid"
  assert_output_contains "Ensure the agent has write permissions to the NRN namespace"
}

@test "deployment/scripts/store_nrn_metadata: includes concurrency metadata when set" {
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
  export LAMBDA_FUNCTION_NAME="my-function"
  export LAMBDA_CURRENT_RESERVED_CONCURRENCY_TYPE="reserved"
  export LAMBDA_CURRENT_RESERVED_CONCURRENCY_VALUE="10"
  export LAMBDA_CURRENT_PROVISIONED_CONCURRENCY_TYPE="provisioned"
  export LAMBDA_CURRENT_PROVISIONED_CONCURRENCY_VALUE="5"

  create_np_mock '{"ok": true}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "reserved_concurrency_type=reserved"
  assert_output_contains "reserved_concurrency_value=10"
  assert_output_contains "provisioned_concurrency_type=provisioned"
  assert_output_contains "provisioned_concurrency_value=5"
}
