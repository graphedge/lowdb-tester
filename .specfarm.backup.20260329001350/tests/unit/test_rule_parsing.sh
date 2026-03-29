#!/bin/bash
# tests/unit/test_rule_parsing.sh
#
# Test suite for rule parsing and constitution logic
# Phase 1 Task T017: Add rule violation logic to data-model.md
#
# Tests parsing of rules.xml and constitution.md
# Converted from BATS to plain bash (no external dependencies)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TESTS_DIR/test_helper.sh"

PASS=0
FAIL=0

_setup_rules_env() {
  cat > constitution.md << 'CONST'
# Project Constitution

## Rules

1. **auth-jwt**: All authentication must use JWT tokens
2. **no-globals**: Shell scripts must not use global variables
3. **test-first**: All features must have tests before implementation
CONST

  cat > .specfarm/rules.xml << 'RULES'
<rules>
<rule id="auth-jwt" immutable="true" available-from="Phase 1"><description>Auth must use JWT</description></rule>
<rule id="no-globals" immutable="false" available-from="Phase 1"><description>No global variables in scripts</description></rule>
<rule id="test-first" immutable="true" available-from="Phase 1"><description>Test-first development (TDD)</description></rule>
</rules>
RULES
}

_run_test() {
  local name="$1"
  local func="$2"
  local test_root
  test_root=$(mktemp -d)
  mkdir -p "$test_root/.specfarm"
  local saved_dir="$PWD"
  cd "$test_root" || { echo "FAIL: $name (cd failed)"; FAIL=$((FAIL+1)); return; }
  _setup_rules_env
  if (export SPECFARM_ROOT="$test_root"; "$func"); then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL+1))
  fi
  cd "$saved_dir" || true
  rm -rf "$test_root"
}

# T017: Add rule violation logic
# Test 1: Parse rules from rules.xml
t017_parse_rules_all_ids() {
  run parse_rules
  [ "$status" -eq 0 ] && [[ "$output" =~ auth-jwt ]] && [[ "$output" =~ no-globals ]] && [[ "$output" =~ test-first ]]
}

# Test 2: Extract rule descriptions
t017_parse_rules_description() {
  run parse_rules "auth-jwt"
  [ "$status" -eq 0 ] && [[ "$output" =~ JWT ]]
}

# Test 3: Handle immutable attribute
t017_parse_rules_immutable_true() {
  run is_immutable "auth-jwt"
  [ "$status" -eq 0 ] && [ "$output" = "true" ]
}

# Test 4: Non-immutable rules
t017_parse_rules_immutable_false() {
  run is_immutable "no-globals"
  [ "$status" -eq 0 ] && [ "$output" = "false" ]
}

# Test 5: Filter rules by phase (available-from)
t017_parse_rules_by_phase() {
  run parse_rules_for_phase "Phase 1"
  [ "$status" -eq 0 ] && [[ "$output" =~ auth-jwt ]]
}

# Test 6: Empty rules.xml returns empty list
t017_parse_rules_empty_xml() {
  echo "<rules></rules>" > .specfarm/rules.xml
  run parse_rules
  [ "$status" -eq 0 ] && [ -z "$output" ]
}

# Test 7: Malformed XML handling (graceful failure)
t017_parse_rules_malformed_xml() {
  echo "<rules><rule id='bad'" > .specfarm/rules.xml
  run parse_rules
  [ "$status" -ne 0 ] || [ -z "$output" ]
}

# Test 8: Rule count accuracy
t017_count_rules_correct() {
  _setup_rules_env
  run count_rules
  [ "$status" -eq 0 ] && [ "$output" = "3" ]
}

# Test 9: Read constitution.md
t017_read_constitution() {
  run read_constitution
  [ "$status" -eq 0 ] && [[ "$output" =~ "Project Constitution" ]]
}

# Test 10: Validate rules.xml format (single-line format)
t017_rules_xml_single_line() {
  _setup_rules_env
  run bash -c "grep -c '<rule ' .specfarm/rules.xml"
  [ "$status" -eq 0 ] && [ "$output" = "3" ]
}

echo "=== Unit Tests: Rule Parsing ==="
_run_test "T017: parse_rules extracts all rule IDs from rules.xml" t017_parse_rules_all_ids
_run_test "T017: parse_rules extracts rule descriptions" t017_parse_rules_description
_run_test "T017: parse_rules identifies immutable rules" t017_parse_rules_immutable_true
_run_test "T017: parse_rules identifies mutable rules" t017_parse_rules_immutable_false
_run_test "T017: parse_rules filters by phase (available-from)" t017_parse_rules_by_phase
_run_test "T017: parse_rules returns empty list when rules.xml empty" t017_parse_rules_empty_xml
_run_test "T017: parse_rules handles malformed XML gracefully" t017_parse_rules_malformed_xml
_run_test "T017: count_rules returns correct total" t017_count_rules_correct
_run_test "T017: read_constitution extracts constitution content" t017_read_constitution
_run_test "T017: rules.xml maintains single-line format for grep parsing" t017_rules_xml_single_line

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
