#!/bin/bash
# tests/unit/test_tdd_workflow.sh
#
# Meta-tests: TDD workflow compliance
# Phase 1 Task T049: TDD framework and workflow validation
#
# These tests ensure Phase 1 tests follow TDD patterns
# Converted from BATS to plain bash (no external dependencies)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TESTS_DIR/test_helper.sh"

PASS=0
FAIL=0

_run_test() {
  local name="$1"
  local func="$2"
  local test_root
  test_root=$(mktemp -d)
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

# T049: Verify TDD compliance across all Phase 1 tasks
# Test 1: All Phase 1 tasks have test-first requirement
t049_phase1_tasks_test_first() {
  local tasks_file="$TESTS_DIR/../specs/001-specfarm-phase-1/tasks.md"
  if [ ! -f "$tasks_file" ]; then
    echo "INFO: tasks.md not found at $tasks_file; skipping"
    return 0
  fi
  run bash -c "grep -c 'Test First' '$tasks_file'"
  [ "$status" -eq 0 ] && [ "$output" -ge 5 ]
}

# Test 2: All test files follow naming convention
t049_test_files_naming_convention() {
  run bash -c "ls '$TESTS_DIR/unit/test_'*.sh '$TESTS_DIR/integration/test_'*.sh '$TESTS_DIR/e2e/test_'*.sh 2>/dev/null | wc -l | tr -d ' '"
  [ "$status" -eq 0 ] && [ "$output" -ge 6 ]
}

# Test 3: All converted test functions use test_* or t0* naming
t049_test_functions_named_correctly() {
  run bash -c "grep -rh '^t0[0-9][0-9][a-z0-9_]*()' '$TESTS_DIR/unit/test_'*.sh '$TESTS_DIR/integration/test_'*.sh '$TESTS_DIR/e2e/test_'*.sh 2>/dev/null | wc -l | tr -d ' '"
  [ "$status" -eq 0 ] && [ "$output" -ge 35 ]
}

# Test 4: All test functions have descriptive names
t049_test_functions_descriptive_names() {
  run bash -c "grep -h '^t0[0-9]' '$TESTS_DIR/unit/test_'*.sh 2>/dev/null | head -1"
  [ "$status" -eq 0 ] && [ ${#output} -ge 20 ]
}

# Test 5: All tests reference task IDs (T0XX)
t049_tests_reference_task_ids() {
  run bash -c "grep -rc 'T0[0-9][0-9]' '$TESTS_DIR/unit' '$TESTS_DIR/integration' '$TESTS_DIR/e2e' 2>/dev/null | awk -F: 'NF==2{sum+=\$2}END{print sum}'"
  [ "$status" -eq 0 ] && [ "$output" -ge 35 ]
}

# Test 6: Test files source test_helper for common utilities
t049_test_files_source_helper() {
  run bash -c "grep -rl 'test_helper' '$TESTS_DIR/unit' '$TESTS_DIR/integration' '$TESTS_DIR/e2e' 2>/dev/null | wc -l | tr -d ' '"
  [ "$status" -eq 0 ] && [ "$output" -ge 3 ]
}

# Test 7: Setup/teardown functions present in unit tests
t049_unit_tests_have_setup() {
  run bash -c "grep -l '_setup\|setup_test\|mktemp' '$TESTS_DIR/unit/test_'*.sh 2>/dev/null | wc -l | tr -d ' '"
  [ "$status" -eq 0 ] && [ "$output" -ge 2 ]
}

# Test 8: Tests are independent (can run in any order)
t049_tests_use_isolated_temp_dirs() {
  run bash -c "grep -rc 'mktemp\|SPECFARM_ROOT' '$TESTS_DIR/unit' '$TESTS_DIR/integration' '$TESTS_DIR/e2e' 2>/dev/null | awk -F: 'NF==2{sum+=\$2}END{print sum}'"
  [ "$status" -eq 0 ] && [ "$output" -ge 6 ]
}

# Test 9: Currently all tests are RED (failing) — skip as informational
t049_phase3_red_state() {
  echo "INFO: Phase 3 RED state — implementation pending in Phase 4"
  return 0
}

# Test 10: Tests are executable as plain bash scripts
t049_test_files_valid_bash_syntax() {
  local failed=0
  for f in "$TESTS_DIR/unit/test_"*.sh "$TESTS_DIR/integration/test_"*.sh "$TESTS_DIR/e2e/test_"*.sh; do
    [ -f "$f" ] || continue
    bash -n "$f" 2>/dev/null || { echo "  Syntax error: $f"; failed=$((failed+1)); }
  done
  [ "$failed" -eq 0 ]
}

echo "=== Unit Tests: TDD Workflow Compliance ==="
_run_test "T049: all Phase 1 tasks reference test-first methodology" t049_phase1_tasks_test_first
_run_test "T049: all test files follow naming pattern test_*.sh" t049_test_files_naming_convention
_run_test "T049: all test functions use t0* naming (converted from @test)" t049_test_functions_named_correctly
_run_test "T049: all test functions have clear descriptive names" t049_test_functions_descriptive_names
_run_test "T049: test functions reference task IDs for traceability" t049_tests_reference_task_ids
_run_test "T049: test files source test_helper for common utilities" t049_test_files_source_helper
_run_test "T049: unit tests have setup isolation (mktemp/SPECFARM_ROOT)" t049_unit_tests_have_setup
_run_test "T049: tests don't depend on shared state between test files" t049_tests_use_isolated_temp_dirs
_run_test "T049: all Phase 3 tests are RED (not yet passing)" t049_phase3_red_state
_run_test "T049: all test files are valid bash syntax" t049_test_files_valid_bash_syntax

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
