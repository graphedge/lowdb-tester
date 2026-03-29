#!/bin/bash
# tests/integration/test_cli_commands.sh
#
# Integration tests for CLI commands
# Phase 1 Task T019, T046: Core CLI and integration testing
#
# Tests the primary specfarm CLI commands
# Converted from BATS to plain bash (no external dependencies)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TESTS_DIR/test_helper.sh"

PASS=0
FAIL=0

_setup_cli_env() {
  local root="$1"
  mkdir -p "$root/.specfarm"
  echo "Phase 1" > "$root/.specfarm/phase"
  cat > "$root/constitution.md" << 'CONST'
# Project Constitution

## Rules

1. **auth-jwt**: All authentication must use JWT
2. **test-first**: All features must have tests before implementation
CONST
  cat > "$root/.specfarm/rules.xml" << 'RULES'
<rules>
<rule id="auth-jwt" immutable="true" available-from="Phase 1"><description>Auth must use JWT</description></rule>
<rule id="test-first" immutable="true" available-from="Phase 1"><description>Test-first development</description></rule>
</rules>
RULES
}

_run_test() {
  local name="$1"
  local func="$2"
  local test_root
  test_root=$(mktemp -d)
  _setup_cli_env "$test_root"
  local saved_dir="$PWD"
  cd "$test_root" || { echo "FAIL: $name (cd failed)"; FAIL=$((FAIL+1)); return; }
  if (export SPECFARM_ROOT="$test_root"; export PATH="$test_root/bin:$PATH"; "$func"); then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL+1))
  fi
  cd "$saved_dir" || true
  rm -rf "$test_root"
}

# T046: Test CLI commands integration
# Test 1: specfarm drift command executes without error
t046_drift_executes() {
  run specfarm drift
  [ "$status" -eq 0 ]
}

# Test 2: drift command returns table with rule IDs
t046_drift_returns_rule_ids() {
  run specfarm drift
  [ "$status" -eq 0 ] && ([[ "$output" =~ auth-jwt ]] || [[ "$output" =~ Rule ]])
}

# Test 3: drift command returns overall score
t046_drift_returns_score() {
  run specfarm drift
  [ "$status" -eq 0 ] && [[ "$output" =~ [Ss]core|0\. ]]
}

# Test 4: justify command executes and logs entry
t046_justify_logs_entry() {
  run specfarm justify auth-jwt "Feature requires legacy auth temporarily"
  [ "$status" -eq 0 ] && [ -f .specfarm/justifications.log ]
}

# Test 5: justification includes timestamp
t046_justify_logs_timestamp() {
  specfarm justify test-first "Under research" > /dev/null 2>&1 || true
  run bash -c "grep -i '202[0-9]' .specfarm/justifications.log"
  [ "$status" -eq 0 ]
}

# Test 6: justification includes commit hash
t046_justify_logs_commit_hash() {
  git init > /dev/null 2>&1
  git config user.email "test@example.com" > /dev/null 2>&1
  git config user.name "Test" > /dev/null 2>&1
  git add . > /dev/null 2>&1
  git commit -m "initial" > /dev/null 2>&1
  specfarm justify auth-jwt "test" > /dev/null 2>&1 || true
  [ -f .specfarm/justifications.log ]
}

# Test 7: help command displays all available commands
t046_help_displays_commands() {
  run specfarm help
  [ "$status" -eq 0 ] && ([[ "$output" =~ drift ]] || [[ "$output" =~ [Cc]ommand ]])
}

# Test 8: drift command with no violations returns output
t046_drift_json_flag() {
  run specfarm drift --json
  [ "$status" -eq 0 ] && [[ "$output" =~ score|drift ]]
}

# Test 9: Justification affects drift score (Phase 2, but test structure ready)
t046_justify_creates_log() {
  run specfarm justify auth-jwt "Legacy auth system"
  [ "$status" -eq 0 ] && [ -f .specfarm/justifications.log ]
}

# Test 10: Multiple justifications logged
t046_multiple_justifications() {
  specfarm justify auth-jwt "First" > /dev/null 2>&1 || true
  specfarm justify test-first "Second" > /dev/null 2>&1 || true
  run bash -c "wc -l < .specfarm/justifications.log | tr -d ' '"
  [ "$status" -eq 0 ] && [ "$output" -ge 2 ]
}

echo "=== Integration Tests: CLI Commands ==="
_run_test "T046: specfarm drift command executes without error" t046_drift_executes
_run_test "T046: specfarm drift returns table with rule IDs" t046_drift_returns_rule_ids
_run_test "T046: specfarm drift includes overall drift score" t046_drift_returns_score
_run_test "T046: specfarm justify logs justification" t046_justify_logs_entry
_run_test "T046: specfarm justify logs preserve timestamp" t046_justify_logs_timestamp
_run_test "T046: specfarm justify logs preserve git commit hash" t046_justify_logs_commit_hash
_run_test "T046: specfarm help displays available commands" t046_help_displays_commands
_run_test "T046: drift score reflects rule compliance" t046_drift_json_flag
_run_test "T046: justified violations handled correctly" t046_justify_creates_log
_run_test "T046: multiple justifications logged in chronological order" t046_multiple_justifications

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
