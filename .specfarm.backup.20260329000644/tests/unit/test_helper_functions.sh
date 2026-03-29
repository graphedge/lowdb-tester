#!/bin/bash
# tests/unit/test_helper_functions.sh

# Source test helper
. "$(dirname "$0")/../test_helper.sh"

echo "Running helper function tests..."

# Test assert_equals
echo "Testing assert_equals..."
assert_equals "test" "test" "Should pass" || exit 1
(assert_equals "test" "fail" "Should fail" 2>/dev/null) && exit 1
echo "✓ assert_equals passed"

# Test count_tokens_approx
echo "Testing count_tokens_approx..."
tokens=$(count_tokens_approx "one two three")
# 3 * 1.3 = 3.9 -> 4
assert_equals "4" "$tokens" "3 words should be ~4 tokens" || exit 1
echo "✓ count_tokens_approx passed"

# Test validate_rule_match
echo "Testing validate_rule_match..."
validate_rule_match "r1" "This is rule r1" || exit 1
(validate_rule_match "r1" "No match here" 2>/dev/null) && exit 1
echo "✓ validate_rule_match passed"

# Test setup/teardown
echo "Testing setup/teardown..."
setup_test_env
if [[ ! -d "$TEST_TMP_DIR" ]]; then
  echo "TEST_TMP_DIR not created"
  exit 1
fi
if [[ ! -f "$RULES_XML_PATH" ]]; then
  echo "rules.xml not copied"
  exit 1
fi
teardown_test_env
if [[ -d "$TEST_TMP_DIR" ]]; then
  echo "TEST_TMP_DIR not removed"
  exit 1
fi
echo "✓ setup/teardown passed"

echo "ALL HELPER TESTS PASSED"
