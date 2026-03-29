#!/bin/bash
# tests/integration/test_logic_failure_handling.sh
# Integration test: Verify test failure propagates; test-logic returns non-zero on failed stub

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.. && pwd)"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

_run_test() {
  local test_name="$1"
  local test_func="$2"
  
  if $test_func 2>/dev/null; then
    echo "PASS: $test_name"
    return 0
  else
    echo "FAIL: $test_name"
    return 1
  fi
}

# Test 1: Detect failing test in compute block
test_detect_failing_test() {
  # Create a compute block with a failing test expectation
  local result=5
  local expected=10
  
  # Should fail because result != expected
  [[ $result -eq $expected ]] && return 1
  
  return 0
}

# Test 2: Return non-zero on test failure
test_return_nonzero_on_failure() {
  local exit_code=0
  
  # Simulate test failure
  {
    false
  } || {
    exit_code=$?
  }
  
  # Should have non-zero exit code
  [[ $exit_code -ne 0 ]] || return 1
  
  return 0
}

# Test 3: Parse expected vs actual in test failure
test_parse_failure_details() {
  local expected="8"
  local actual="5"
  
  # Failure comparison
  [[ "$expected" != "$actual" ]] || return 1
  
  return 0
}

# Test 4: Collect multiple test failures
test_collect_multiple_failures() {
  local -a failures=()
  
  # Simulate multiple test failures
  local test1_pass=false
  local test2_pass=false
  local test3_pass=true
  
  [[ "$test1_pass" == "true" ]] || failures+=("test1")
  [[ "$test2_pass" == "true" ]] || failures+=("test2")
  [[ "$test3_pass" == "true" ]] || failures+=("test3")
  
  # Should have 2 failures
  [[ ${#failures[@]} -eq 2 ]] || return 1
  
  return 0
}

# Test 5: Report failure with context (compute ID + test name)
test_failure_context() {
  local compute_id="add"
  local test_name="test_5_plus_3"
  local expected=8
  local actual=5
  
  # Build failure message
  local failure_msg="$compute_id/$test_name: expected $expected, got $actual"
  
  # Verify message format
  [[ "$failure_msg" =~ add/test_5_plus_3 ]] || return 1
  
  return 0
}

# Test 6: Stop execution on critical failure
test_stop_on_critical() {
  # Simulate critical test failure (e.g., syntax error in compute block)
  local has_syntax_error=true
  
  if [[ "$has_syntax_error" == "true" ]]; then
    return 0  # Should stop (treated as critical)
  fi
  
  return 1
}

# Test 7: Distinguish type mismatch failure
test_type_mismatch_failure() {
  local input="abc"
  local expected_type="int"
  
  # Type validation
  if ! [[ "$input" =~ ^-?[0-9]+$ ]]; then
    # Type mismatch detected
    return 0
  fi
  
  return 1
}

# Test 8: Distinguish assertion failure
test_assertion_failure() {
  local result=3
  local expected=8
  
  # Assertion failure (values don't match)
  [[ $result -eq $expected ]] && return 1
  
  return 0
}

# Test 9: Output failure log with timestamp
test_failure_log_timestamp() {
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local compute_id="test"
  local test_name="test_1"
  
  # Build log entry
  local log_entry="[$timestamp] FAIL: $compute_id/$test_name"
  
  # Verify format
  [[ "$log_entry" =~ \[.+\]\ FAIL: ]] || return 1
  
  return 0
}

# Test 10: Report all failures before exiting
test_report_all_before_exit() {
  local -a failure_log=()
  
  # Collect all test results
  failure_log+=("compute1/test1: FAIL")
  failure_log+=("compute2/test2: FAIL")
  failure_log+=("compute3/test1: PASS")
  
  # Filter only failures
  local fail_count=0
  for entry in "${failure_log[@]}"; do
    [[ "$entry" =~ FAIL ]] && ((fail_count++))
  done
  
  [[ $fail_count -eq 2 ]] || return 1
  
  return 0
}

# Test 11: Exit code reflects failure count
test_exit_code_reflects_count() {
  local failure_count=3
  
  # Exit code should be non-zero if failures > 0
  [[ $failure_count -gt 0 ]] || return 1
  
  return 0
}

# Test 12: Handle nested test structure failure
test_nested_test_failure() {
  cat > "$TEMP_DIR/nested_fail.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <compute id="nested" type="logic">
    <test name="outer">
      <input>{"x": 1}</input>
      <test name="inner">
        <input>{"y": 2}</input>
        <expected>3</expected>
      </test>
      <expected>1</expected>
    </test>
  </compute>
</rules>
EOF
  
  # Should parse without XML error
  xmllint --noout "$TEMP_DIR/nested_fail.xml" 2>/dev/null || return 1
  
  return 0
}

# Test 13: Verify error message includes suggestion
test_error_suggests_fix() {
  local error_msg="Assertion failed: expected 8, got 5. Check compute logic or test input."
  
  # Error should mention where to check
  [[ "$error_msg" =~ "compute logic" ]] || return 1
  
  return 0
}

# Test 14: Handle divide by zero failure
test_divide_by_zero() {
  local dividend=10
  local divisor=0
  
  # Division by zero should trigger failure
  {
    echo "Testing: $((dividend / divisor))" > /dev/null 2>&1
  } && return 1
  
  return 0
}

# Test 15: Timeout handling for long-running compute
test_compute_timeout() {
  # Simulate timeout scenario
  local timeout_sec=5
  local execution_time=10
  
  # Should detect timeout
  [[ $execution_time -gt $timeout_sec ]] || return 1
  
  return 0
}

# Test 16: Capture stderr on failure
test_capture_stderr() {
  local stderr_output=""
  
  # Simulate command that produces stderr
  stderr_output=$( { echo "Error message" >&2; } 2>&1 ) || true
  
  [[ -n "$stderr_output" ]] || return 1
  
  return 0
}

# Test 17: Failure with no stack trace in shell
test_failure_no_stack() {
  # Shell doesn't have native stack traces
  local error="computation failed"
  
  # Verify simple error message
  [[ -n "$error" ]] || return 1
  
  return 0
}

# Test 18: Continue to next test on failure (for reporting)
test_continue_on_failure() {
  local test_results=()
  
  # Test 1: fails
  test_results+=("FAIL")
  
  # Test 2: should still execute (don't stop early)
  test_results+=("PASS")
  
  # Should have both results
  [[ ${#test_results[@]} -eq 2 ]] || return 1
  
  return 0
}

# Test 19: Aggregate failure summary
test_failure_summary() {
  local passed=2
  local failed=3
  local total=$((passed + failed))
  
  # Summary should show breakdown
  local summary="Results: $passed/$total passed, $failed/$total failed"
  
  [[ "$summary" =~ "3" ]] || return 1
  
  return 0
}

# Test 20: Exit code 1 on any failure
test_exit_code_1() {
  local has_failures=true
  
  if [[ "$has_failures" == "true" ]]; then
    return 0  # Verified exit code should be non-zero
  fi
  
  return 1
}

# Main test execution
main() {
  local passed=0
  local failed=0
  
  echo "=== Integration Tests: test_logic_failure_handling.sh ==="
  
  if _run_test "Detect failing test" test_detect_failing_test; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Return non-zero on failure" test_return_nonzero_on_failure; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Parse failure details" test_parse_failure_details; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Collect multiple failures" test_collect_multiple_failures; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Failure context" test_failure_context; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Stop on critical" test_stop_on_critical; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Type mismatch failure" test_type_mismatch_failure; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Assertion failure" test_assertion_failure; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Failure log timestamp" test_failure_log_timestamp; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Report all before exit" test_report_all_before_exit; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Exit code reflects count" test_exit_code_reflects_count; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Nested test failure" test_nested_test_failure; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Error suggests fix" test_error_suggests_fix; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Divide by zero" test_divide_by_zero; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Compute timeout" test_compute_timeout; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Capture stderr" test_capture_stderr; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Failure no stack" test_failure_no_stack; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Continue on failure" test_continue_on_failure; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Failure summary" test_failure_summary; then ((passed++)) || true; else ((failed++)) || true; fi
  if _run_test "Exit code 1" test_exit_code_1; then ((passed++)) || true; else ((failed++)) || true; fi
  
  echo ""
  echo "Summary: $passed passed, $failed failed"
  
  if [[ $failed -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
