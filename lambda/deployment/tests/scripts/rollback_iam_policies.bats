#!/usr/bin/env bats

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  HELPERS_DIR="$TEST_DIR/helpers"
  LAMBDA_DIR="$(cd "$TEST_DIR/../../.." && pwd)"

  load "$HELPERS_DIR/test_helper.bash"
  load "$HELPERS_DIR/mock_context.bash"

  setup_test_env
  export SERVICE_PATH="$LAMBDA_DIR"

  SCRIPT="$LAMBDA_DIR/deployment/scripts/rollback_iam_policies"

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

# Helper: create a mock aws script
create_aws_mock() {
  local response="$1"
  local exit_code="${2:-0}"
  echo "$response" > "$MOCK_BIN_DIR/aws_response.txt"
  cat > "$MOCK_BIN_DIR/aws" <<'OUTERSCRIPT'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cat "$SCRIPT_DIR/aws_response.txt"
OUTERSCRIPT
  echo "exit $exit_code" >> "$MOCK_BIN_DIR/aws"
  chmod +x "$MOCK_BIN_DIR/aws"
}

@test "deployment/scripts/rollback_iam_policies: fails when LAMBDA_ROLE_NAME is not set" {
  unset LAMBDA_ROLE_NAME
  export DEPLOYMENT_ID="deploy-123"
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"

  run bash "$SCRIPT"

  assert_failure
  assert_line "❌ LAMBDA_ROLE_NAME is required"
  assert_output_contains "💡 Possible causes:"
  assert_output_contains "Environment variable not set by the deployment pipeline"
  assert_output_contains "Lambda execution role was not created during scope provisioning"
  assert_output_contains "🔧 How to fix:"
  assert_output_contains "Verify the scope has a valid IAM role configured"
  assert_output_contains "Check that LAMBDA_ROLE_NAME is exported before this script runs"
}

@test "deployment/scripts/rollback_iam_policies: fails when DEPLOYMENT_ID is not set" {
  export LAMBDA_ROLE_NAME="my-role"
  unset DEPLOYMENT_ID
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"

  run bash "$SCRIPT"

  assert_failure
  assert_line "❌ DEPLOYMENT_ID is required"
  assert_output_contains "💡 Possible causes:"
  assert_output_contains "Deployment context not properly initialized"
  assert_output_contains "Script invoked outside of a deployment pipeline"
  assert_output_contains "🔧 How to fix:"
  assert_output_contains "Ensure this script is called from within a nullplatform deployment flow"
  assert_output_contains "Check that DEPLOYMENT_ID is set in the environment"
}

@test "deployment/scripts/rollback_iam_policies: fails when SCOPE_NRN is not set" {
  export LAMBDA_ROLE_NAME="my-role"
  export DEPLOYMENT_ID="deploy-123"
  unset SCOPE_NRN

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

@test "deployment/scripts/rollback_iam_policies: skips when no policies to rollback" {
  export LAMBDA_ROLE_NAME="my-role"
  export DEPLOYMENT_ID="deploy-123"
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"

  create_np_mock '{"AWS_LAMBDA_MERGED_POLICIES": "[]"}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "⏭️  No policies to rollback"
}

@test "deployment/scripts/rollback_iam_policies: skips when policies is null" {
  export LAMBDA_ROLE_NAME="my-role"
  export DEPLOYMENT_ID="deploy-123"
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"

  create_np_mock '{"AWS_LAMBDA_MERGED_POLICIES": null}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "⏭️  No policies to rollback"
}

@test "deployment/scripts/rollback_iam_policies: removes single policy successfully" {
  export LAMBDA_ROLE_NAME="my-role"
  export DEPLOYMENT_ID="deploy-123"
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"

  create_np_mock '{"AWS_LAMBDA_MERGED_POLICIES": "[{\"name\":\"sqs-access\"}]"}'
  create_aws_mock ""

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "📝 Rolling back IAM policies..."
  assert_output_contains "role_name=my-role"
  assert_output_contains "deployment_id=deploy-123"
  assert_output_contains "Found 1 policies to remove from role=my-role"
  assert_output_contains "Removing policy: sqs-access-deploy-123 from role=my-role"
  assert_output_contains "Policy sqs-access-deploy-123 removed"
  assert_output_contains "✨ IAM policies rolled back successfully for role=my-role deployment=deploy-123"
}

@test "deployment/scripts/rollback_iam_policies: logs policy removal with correct naming convention" {
  export LAMBDA_ROLE_NAME="my-role"
  export DEPLOYMENT_ID="deploy-123"
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"

  create_np_mock '{"AWS_LAMBDA_MERGED_POLICIES": "[{\"name\":\"sqs-access\"}]"}'
  create_aws_mock ""

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "Removing policy: sqs-access-deploy-123 from role=my-role"
  assert_output_contains "Policy sqs-access-deploy-123 removed"
}

@test "deployment/scripts/rollback_iam_policies: succeeds even when aws delete-role-policy fails" {
  export LAMBDA_ROLE_NAME="my-role"
  export DEPLOYMENT_ID="deploy-123"
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"

  create_np_mock '{"AWS_LAMBDA_MERGED_POLICIES": "[{\"name\":\"sqs-access\"}]"}'
  create_aws_mock "NoSuchEntityException: Policy not found" 1

  run bash "$SCRIPT"

  # Script uses || true for delete, so it should still succeed
  assert_success
  assert_output_contains "✨ IAM policies rolled back successfully for role=my-role deployment=deploy-123"
}

@test "deployment/scripts/rollback_iam_policies: logs deployment-scoped NRN in output" {
  export LAMBDA_ROLE_NAME="my-role"
  export DEPLOYMENT_ID="deploy-123"
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"

  create_np_mock '{"AWS_LAMBDA_MERGED_POLICIES": "[]"}'

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "Reading merged policies from NRN=organization=1:account=2:namespace=3:application=4:scope=5:deployment=deploy-123..."
}

@test "deployment/scripts/rollback_iam_policies: handles multiple policies removal" {
  export LAMBDA_ROLE_NAME="my-role"
  export DEPLOYMENT_ID="deploy-456"
  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"

  create_np_mock '{"AWS_LAMBDA_MERGED_POLICIES": "[{\"name\":\"sqs-access\"},{\"name\":\"s3-read\"}]"}'
  create_aws_mock ""

  run bash "$SCRIPT"

  assert_success
  assert_output_contains "Found 2 policies to remove from role=my-role"
  assert_output_contains "Removing policy: sqs-access-deploy-456 from role=my-role"
  assert_output_contains "Policy sqs-access-deploy-456 removed"
  assert_output_contains "Removing policy: s3-read-deploy-456 from role=my-role"
  assert_output_contains "Policy s3-read-deploy-456 removed"
}
