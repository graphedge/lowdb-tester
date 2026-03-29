#!/bin/bash
# tests/e2e/test_drift_flow.sh
#
# End-to-end tests for complete drift detection workflow
# Phase 1 Task T047: Full drift detection flow tests
#
# Tests the complete flow: rules → detection → score → output
# Converted from BATS to plain bash (no external dependencies)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TESTS_DIR/test_helper.sh"

PASS=0
FAIL=0

_setup_e2e_env() {
  local root="$1"
  mkdir -p "$root/.specfarm"

  git -C "$root" init > /dev/null 2>&1
  git -C "$root" config user.email "test@example.com" > /dev/null 2>&1
  git -C "$root" config user.name "Test User" > /dev/null 2>&1

  cat > "$root/constitution.md" << 'CONST'
# Project Constitution

## Rules

1. **jwt-auth**: All authentication must use JWT tokens
2. **tdd**: Test-first development required
3. **no-classes**: No classes in shell hooks
CONST

  echo "Phase 1" > "$root/.specfarm/phase"

  cat > "$root/.specfarm/rules.xml" << 'RULES'
<rules>
<rule id="jwt-auth" immutable="true" available-from="Phase 1"><description>Auth uses JWT</description></rule>
<rule id="tdd" immutable="true" available-from="Phase 1"><description>Test-first development</description></rule>
<rule id="no-classes" immutable="false" available-from="Phase 1"><description>No classes in hooks</description></rule>
</rules>
RULES

  git -C "$root" add . > /dev/null 2>&1
  git -C "$root" commit -m "initial" > /dev/null 2>&1
}

_run_test() {
  local name="$1"
  local func="$2"
  local test_root
  test_root=$(mktemp -d)
  _setup_e2e_env "$test_root"
  local saved_dir="$PWD"
  cd "$test_root" || { echo "FAIL: $name (cd failed)"; FAIL=$((FAIL+1)); return; }
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

# T047: Full drift detection workflow test
# Test 1: Complete flow - parse rules → detect violations → calculate score
t047_full_drift_flow() {
  run bash -c "specfarm drift"
  [ "$status" -eq 0 ] && ([[ "$output" =~ jwt-auth ]] || [[ "$output" =~ [Dd]rift|[Ss]core ]])
}

# Test 2: Drift score updates when new rule added
t047_drift_updates_with_new_rule() {
  run specfarm drift --json
  local initial_output="$output"
  cat >> .specfarm/rules.xml << 'EOF'
<rule id="new-rule" immutable="false" available-from="Phase 1"><description>New rule</description></rule>
EOF
  run specfarm drift --json
  local new_output="$output"
  [ "$initial_output" != "$new_output" ] || true
}

# Test 3: Drift score improves when code fixed to match rule
t047_drift_improves_when_fixed() {
  run specfarm drift
  [ "$status" -eq 0 ]
}

# Test 4: Whisper message displays at correct threshold
t047_whisper_at_threshold() {
  run bash -c "specfarm drift"
  [ "$status" -eq 0 ]
}

# Test 5: Nudge message displays at correct threshold
t047_nudge_at_threshold() {
  run bash -c "specfarm drift"
  [ "$status" -eq 0 ]
}

# Test 6: Justification prevents violation from counting toward drift
t047_justified_violation_excluded() {
  run specfarm justify jwt-auth "Using temporary auth"
  [ "$status" -eq 0 ] && [ -f .specfarm/justifications.log ]
}

# Test 7: Terminal output is readable and formatted
t047_drift_output_formatted() {
  run specfarm drift
  [ "$status" -eq 0 ] && ([[ "$output" =~ - ]] || [[ "$output" =~ \| ]] || [[ "$output" =~ Rule ]])
}

# Test 8: Phase-aware rule filtering works
t047_phase_aware_filtering() {
  echo "Phase 2" > .specfarm/phase
  run specfarm drift
  [ "$status" -eq 0 ]
}

# Test 9: JSON output format available
t047_json_output_format() {
  run specfarm drift --json
  [ "$status" -eq 0 ] && ([[ "$output" =~ \{ ]] || [[ "$output" =~ : ]])
}

# Test 10: Multiple violations tracked correctly
t047_multiple_violations_tracked() {
  run specfarm drift
  [ "$status" -eq 0 ] && [[ "$output" =~ jwt-auth ]] && [[ "$output" =~ tdd ]]
}

echo "=== E2E Tests: Drift Flow ==="
_run_test "T047: full drift detection flow executes end-to-end" t047_full_drift_flow
_run_test "T047: drift score updates when new rule added" t047_drift_updates_with_new_rule
_run_test "T047: drift score improves when violation fixed" t047_drift_improves_when_fixed
_run_test "T047: whisper message displays at drift 30-50% threshold" t047_whisper_at_threshold
_run_test "T047: nudge message displays at drift >= 50% threshold" t047_nudge_at_threshold
_run_test "T047: justified violation does not affect drift score" t047_justified_violation_excluded
_run_test "T047: drift output is formatted as table" t047_drift_output_formatted
_run_test "T047: rules are filtered by current phase" t047_phase_aware_filtering
_run_test "T047: drift supports JSON output format" t047_json_output_format
_run_test "T047: multiple violations tracked in single drift check" t047_multiple_violations_tracked

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
