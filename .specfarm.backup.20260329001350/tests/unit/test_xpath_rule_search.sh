#!/bin/bash
# tests/unit/test_xpath_rule_search.sh

. "$(dirname "$0")/../test_helper.sh"

AGENT=".specfarm/agents/gather-rules-agent.sh"

echo "Running XPath rule search tests..."

# Extract color vars, logging helpers, and target functions to a temp file
# to avoid running main() which is at the end of the agent script.
TMP_FUNC_FILE=$(mktemp)
{
    # Logging functions (color vars already defined by test_helper.sh)
    sed -n '/^log_section() {/,/^}/p' "$AGENT"
    sed -n '/^log_info() {/,/^}/p' "$AGENT"
    sed -n '/^log_done() {/,/^}/p' "$AGENT"
    sed -n '/^log_warn() {/,/^}/p' "$AGENT"
    sed -n '/^log_error() {/,/^}/p' "$AGENT"
    # Target functions
    sed -n '/^extract_task_keywords() {/,/^}/p' "$AGENT"
    sed -n '/^search_rules_xpath() {/,/^}/p' "$AGENT"
} > "$TMP_FUNC_FILE"
export RULES_XML_PATH="$(dirname "${BASH_SOURCE[0]}")/../fixtures/sample-rules.xml"
# shellcheck disable=SC1090
. "$TMP_FUNC_FILE"
rm "$TMP_FUNC_FILE"

# Test 1: Search rules by name keyword 'Bash'
echo "Test 1: Search by name keyword 'Bash'"
res=$(search_rules_xpath "Bash")
if echo "$res" | grep -q "r_bash_001"; then
  echo "✓ PASS: Found r_bash_001"
else
  echo "✗ FAIL: r_bash_001 not found in '$res'"
  exit 1
fi

# Test 2: Search by description keyword 'slashes'
echo "Test 2: Search by description 'slashes'"
res=$(search_rules_xpath "slashes")
if echo "$res" | grep -q "r_path_001"; then
  echo "✓ PASS: Found r_path_001"
else
  echo "✗ FAIL: r_path_001 not found in '$res'"
  exit 1
fi

# Test 3: Search by scope 'repository'
echo "Test 3: Search by scope 'repository'"
res=$(search_rules_xpath "repository")
# Expected: several including r_path_001, r_git_001, r_module_001, r_ps_001, r_alias_001
# We check for a few key ones.
if echo "$res" | grep -q "r_path_001" && echo "$res" | grep -q "r_git_001" && echo "$res" | grep -q "r_module_001"; then
  echo "✓ PASS: Found multiple rules by scope"
else
  echo "✗ FAIL: Expected rules not found by scope in '$res'"
  exit 1
fi

# Test 4: Handle no matches gracefully
echo "Test 4: No matches"
res=$(search_rules_xpath "nonexistent_keyword")
if [[ -z "$res" ]]; then
  echo "✓ PASS: No matches returned empty string"
else
  echo "✗ FAIL: Unexpected results '$res' when no matches found"
  exit 1
fi

# Test 5: Handle xmllint not installed (mocked via XMLLINT_CMD)
echo "Test 5: xmllint not installed (mocked)"
output=$(RULES_XML_PATH="$(dirname "${BASH_SOURCE[0]}")/../fixtures/sample-rules.xml" XMLLINT_CMD="nonexistent_xmllint_for_test" \
    bash -c '. tests/test_helper.sh
             AGENT=".specfarm/agents/gather-rules-agent.sh"
             TMP=$(mktemp)
             for fn in log_section log_info log_done log_warn log_error extract_task_keywords search_rules_xpath; do
                 sed -n "/^${fn}() {/,/^}/p" "$AGENT" >> "$TMP"
             done
             . "$TMP"; rm "$TMP"
             search_rules_xpath "Bash" 2>&1' 2>&1 || true)
if echo "$output" | grep -qi "xmllint"; then
  echo "✓ PASS: xmllint not found error detected"
else
  echo "✗ FAIL: Expected xmllint error message not found in output:"
  echo "$output"
  exit 1
fi


echo "All tests passed"
