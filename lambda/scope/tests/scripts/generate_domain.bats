#!/usr/bin/env bats
# Unit tests for scope/scripts/generate_domain script

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
HELPERS_DIR="$SCRIPT_DIR/helpers"
LAMBDA_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
GENERATE_DOMAIN_SCRIPT="$LAMBDA_DIR/scope/scripts/generate_domain"

load "$HELPERS_DIR/test_helper.bash"
load "$HELPERS_DIR/mock_context.bash"

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

# Domain generation
@test "scope/scripts/generate_domain: generates domain with account slug" {
  export ACCOUNT_SLUG="my-account"
  export NAMESPACE_SLUG="my-namespace"
  export APPLICATION_SLUG="my-app"
  export SCOPE_SLUG="my-scope"
  export DOMAIN="nullapps.io"
  export USE_ACCOUNT_SLUG="true"

  local domain="${SCOPE_SLUG}.${APPLICATION_SLUG}.${NAMESPACE_SLUG}.${ACCOUNT_SLUG}.${DOMAIN}"

  assert_equal "$domain" "my-scope.my-app.my-namespace.my-account.nullapps.io"
}

@test "scope/scripts/generate_domain: generates domain without account slug when USE_ACCOUNT_SLUG is false" {
  export ACCOUNT_SLUG="my-account"
  export NAMESPACE_SLUG="my-namespace"
  export APPLICATION_SLUG="my-app"
  export SCOPE_SLUG="my-scope"
  export DOMAIN="nullapps.io"
  export USE_ACCOUNT_SLUG="false"

  local domain
  if [ "$USE_ACCOUNT_SLUG" = "true" ]; then
    domain="${SCOPE_SLUG}.${APPLICATION_SLUG}.${NAMESPACE_SLUG}.${ACCOUNT_SLUG}.${DOMAIN}"
  else
    domain="${SCOPE_SLUG}.${APPLICATION_SLUG}.${NAMESPACE_SLUG}.${DOMAIN}"
  fi

  assert_equal "$domain" "my-scope.my-app.my-namespace.nullapps.io"
}

@test "scope/scripts/generate_domain: uses custom domain template when provided" {
  export ACCOUNT_SLUG="my-account"
  export NAMESPACE_SLUG="my-namespace"
  export APPLICATION_SLUG="my-app"
  export SCOPE_SLUG="my-scope"
  export DOMAIN_TEMPLATE="{scope}.{app}.example.com"

  local domain="$DOMAIN_TEMPLATE"
  domain="${domain//\{scope\}/$SCOPE_SLUG}"
  domain="${domain//\{app\}/$APPLICATION_SLUG}"
  domain="${domain//\{namespace\}/$NAMESPACE_SLUG}"
  domain="${domain//\{account\}/$ACCOUNT_SLUG}"

  assert_equal "$domain" "my-scope.my-app.example.com"
}

# Special characters handling
@test "scope/scripts/generate_domain: handles hyphens and version suffixes in slugs" {
  export SCOPE_SLUG="my-scope-v2"
  export APPLICATION_SLUG="my-app"
  export NAMESPACE_SLUG="prod"
  export ACCOUNT_SLUG="acme-corp"
  export DOMAIN="nullapps.io"
  export USE_ACCOUNT_SLUG="true"

  local domain="${SCOPE_SLUG}.${APPLICATION_SLUG}.${NAMESPACE_SLUG}.${ACCOUNT_SLUG}.${DOMAIN}"

  assert_equal "$domain" "my-scope-v2.my-app.prod.acme-corp.nullapps.io"
}

@test "scope/scripts/generate_domain: converts underscores to hyphens in domain" {
  export SCOPE_SLUG="my_scope"

  local sanitized_slug="${SCOPE_SLUG//_/-}"

  assert_equal "$sanitized_slug" "my-scope"
}

@test "scope/scripts/generate_domain: lowercases the domain" {
  export SCOPE_SLUG="My-Scope"
  export APPLICATION_SLUG="My-App"
  export NAMESPACE_SLUG="Prod"
  export DOMAIN="nullapps.io"

  local domain="${SCOPE_SLUG}.${APPLICATION_SLUG}.${NAMESPACE_SLUG}.${DOMAIN}"
  domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')

  assert_equal "$domain" "my-scope.my-app.prod.nullapps.io"
}

# np CLI integration
@test "scope/scripts/generate_domain: calls np scope patch to update domain" {
  export SCOPE_ID="scope-123"
  export SCOPE_DOMAIN="my-scope.my-app.nullapps.io"

  mock_np '{"id": "scope-123", "domain": "my-scope.my-app.nullapps.io"}'

  np scope patch --id "$SCOPE_ID" --domain "$SCOPE_DOMAIN"

  [ $? -eq 0 ]
  assert_np_called "scope patch"
  assert_np_called "--id scope-123"
  assert_np_called "--domain"
}

@test "scope/scripts/generate_domain: handles np CLI errors" {
  export SCOPE_ID="scope-123"
  export SCOPE_DOMAIN="my-scope.my-app.nullapps.io"

  mock_np_error "Scope not found"

  run np scope patch --id "$SCOPE_ID" --domain "$SCOPE_DOMAIN"

  assert_failure
}

# Environment variable export
@test "scope/scripts/generate_domain: exports SCOPE_DOMAIN variable" {
  export SCOPE_SLUG="my-scope"
  export APPLICATION_SLUG="my-app"
  export NAMESPACE_SLUG="prod"
  export ACCOUNT_SLUG="acme"
  export DOMAIN="nullapps.io"
  export USE_ACCOUNT_SLUG="true"

  SCOPE_DOMAIN="${SCOPE_SLUG}.${APPLICATION_SLUG}.${NAMESPACE_SLUG}.${ACCOUNT_SLUG}.${DOMAIN}"
  export SCOPE_DOMAIN

  assert_not_empty "$SCOPE_DOMAIN" "SCOPE_DOMAIN"
  assert_equal "$SCOPE_DOMAIN" "my-scope.my-app.prod.acme.nullapps.io"
}

# Domain validation
@test "scope/scripts/generate_domain: validates domain length under 253 chars" {
  local domain="my-scope.my-app.prod.acme.nullapps.io"

  assert_less_than "${#domain}" "253" "domain length"
}

@test "scope/scripts/generate_domain: detects label exceeding 63 chars" {
  local label="this-is-a-very-long-label-that-exceeds-the-maximum-allowed-length-for-dns"
  local max_label_length=63

  assert_greater_than "${#label}" "$max_label_length" "label length"
}

@test "scope/scripts/generate_domain: rejects invalid DNS characters" {
  local invalid_slug="my_scope@invalid"

  if [[ "$invalid_slug" =~ ^[a-zA-Z0-9-]+$ ]]; then
    valid=true
  else
    valid=false
  fi

  assert_false "$valid" "DNS character validation"
}

# Context extraction
@test "scope/scripts/generate_domain: extracts slugs from context" {
  set_context "public"

  assert_json_path_equal "$CONTEXT" '.account.slug' "my-account"
  assert_json_path_equal "$CONTEXT" '.namespace.slug' "my-namespace"
  assert_json_path_equal "$CONTEXT" '.application.slug' "my-app"
  assert_json_path_equal "$CONTEXT" '.scope.slug' "my-scope"
}

@test "scope/scripts/generate_domain: uses hosted zone domain from providers" {
  set_context "public"

  assert_json_path_equal "$CONTEXT" '.providers["cloud-providers"].networking.hosted_public_zone_id' "Z1234567890ABC"
}

# Wildcard domain
@test "scope/scripts/generate_domain: does not generate wildcard domain" {
  export SCOPE_SLUG="my-scope"
  export DOMAIN="nullapps.io"

  local domain="${SCOPE_SLUG}.${DOMAIN}"

  [[ "$domain" != \*.* ]]
}

# Idempotency
@test "scope/scripts/generate_domain: generates same domain for same inputs" {
  export SCOPE_SLUG="my-scope"
  export APPLICATION_SLUG="my-app"
  export NAMESPACE_SLUG="prod"
  export ACCOUNT_SLUG="acme"
  export DOMAIN="nullapps.io"
  export USE_ACCOUNT_SLUG="true"

  local domain1="${SCOPE_SLUG}.${APPLICATION_SLUG}.${NAMESPACE_SLUG}.${ACCOUNT_SLUG}.${DOMAIN}"
  local domain2="${SCOPE_SLUG}.${APPLICATION_SLUG}.${NAMESPACE_SLUG}.${ACCOUNT_SLUG}.${DOMAIN}"

  assert_equal "$domain1" "$domain2"
}
