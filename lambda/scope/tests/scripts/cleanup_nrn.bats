#!/usr/bin/env bats

setup() {
  TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  HELPERS_DIR="$TEST_DIR/helpers"
  LAMBDA_DIR="$(cd "$TEST_DIR/../../.." && pwd)"

  load "$HELPERS_DIR/test_helper.bash"
  load "$HELPERS_DIR/mock_context.bash"

  setup_test_env
  export SERVICE_PATH="$LAMBDA_DIR"
  export -f aws np

  export SCOPE_NRN="organization=1:account=2:namespace=3:application=4:scope=5"
}

teardown() {
  teardown_test_env
}

@test "scope/scripts/cleanup_nrn: logs scope NRN" {
  run bash "$LAMBDA_DIR/scope/scripts/cleanup_nrn"

  assert_success
  assert_output_contains "scope_nrn=$SCOPE_NRN"
}

@test "scope/scripts/cleanup_nrn: reports cleanup handled by platform" {
  run bash "$LAMBDA_DIR/scope/scripts/cleanup_nrn"

  assert_success
  assert_output_contains "NRN cleanup handled by platform (automatic on scope deletion)"
}

@test "scope/scripts/cleanup_nrn: outputs full success flow" {
  run bash "$LAMBDA_DIR/scope/scripts/cleanup_nrn"

  assert_success
  assert_output_contains "Cleaning up NRN metadata..."
  assert_output_contains "scope_nrn=organization=1:account=2:namespace=3:application=4:scope=5"
  assert_output_contains "NRN cleanup handled by platform (automatic on scope deletion)"
  assert_line "✨ NRN cleanup complete"
}

@test "scope/scripts/cleanup_nrn: exits with zero status code" {
  run bash "$LAMBDA_DIR/scope/scripts/cleanup_nrn"

  assert_success
}
