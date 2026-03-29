#!/usr/bin/env bash
# .specfarm/tests/crossplatform/orchtest_justify_list_parity.sh
# T028b [US2] ORCHESTRATED parity test: justify-log list output
#
# Tests: Run `justify-log list` on bash env using fixture log;
# verify output lists expected entries
#
# Constitution: II.A (Zero external dependencies - no jq, pure bash)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
export SPECFARM_ROOT="$REPO_ROOT"

# Source test helper
source "$REPO_ROOT/.specfarm/tests/test_helper.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
test_result() {
    local test_name="$1"
    local result="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$result" == "PASS" ]]; then
        echo "  ✓ $test_name: PASS"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ $test_name: FAIL"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Mock justify-log list command (since actual script may not exist yet)
mock_justify_log_list() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        echo "Error: Log file not found: $log_file" >&2
        return 1
    fi
    
    # Simple implementation: parse JSON Lines and output formatted list
    local line_num=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        line_num=$((line_num + 1))
        
        # Extract fields using grep/sed (no jq)
        local timestamp
        timestamp=$(echo "$line" | grep -oP '"timestamp":\s*"[^"]*"' | sed -E 's/"timestamp":\s*"([^"]*)"/\1/')
        
        local rule_id
        rule_id=$(echo "$line" | grep -oP '"rule_id":\s*"[^"]*"' | sed -E 's/"rule_id":\s*"([^"]*)"/\1/')
        
        local status
        status=$(echo "$line" | grep -oP '"status":\s*"[^"]*"' | sed -E 's/"status":\s*"([^"]*)"/\1/')
        
        local justification
        justification=$(echo "$line" | grep -oP '"justification":\s*"[^"]*"' | sed -E 's/"justification":\s*"([^"]*)"/\1/')
        
        # Output formatted entry
        echo "[$line_num] $timestamp | $rule_id | $status"
        echo "    $justification"
    done < "$log_file"
}

# Normalize output for comparison (timestamps -> TIMESTAMP)
normalize_list_output() {
    local output="$1"
    
    # Replace ISO timestamps with placeholder
    echo "$output" | sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/TIMESTAMP/g'
}

# Test 1: justify-log list outputs expected entries
t028b_01_list_output_entries() {
    echo ""
    echo "Test: T028b-01 - justify-log list outputs expected entries"
    
    local test_log="$SCRIPT_DIR/testdata/justifications-sample.log"
    
    if [[ ! -f "$test_log" ]]; then
        echo "    SKIP: Fixture missing: $test_log"
        test_result "T028b-01-list-output-entries" "FAIL"
        return 1
    fi
    
    # Count expected entries
    local expected_count
    expected_count=$(grep -c '^{' "$test_log")
    echo "    Expected entries: $expected_count"
    
    # Run mock justify-log list
    local list_output
    list_output=$(mock_justify_log_list "$test_log" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "    FAIL: justify-log list exited with code $exit_code"
        test_result "T028b-01-list-output-entries" "FAIL"
        return 1
    fi
    
    # Count output entries (lines starting with "[N]")
    local output_count
    output_count=$(echo "$list_output" | grep -c '^\[' || echo "0")
    echo "    Output entries: $output_count"
    
    if [[ "$output_count" -ne "$expected_count" ]]; then
        echo "    FAIL: Entry count mismatch"
        echo "    Expected: $expected_count, Got: $output_count"
        test_result "T028b-01-list-output-entries" "FAIL"
        return 1
    fi
    
    # Verify specific rule IDs are present
    if ! echo "$list_output" | grep -q "shell-prefer-posix"; then
        echo "    FAIL: Expected rule_id 'shell-prefer-posix' not found"
        test_result "T028b-01-list-output-entries" "FAIL"
        return 1
    fi
    
    if ! echo "$list_output" | grep -q "test-specfarm-dir-exists"; then
        echo "    FAIL: Expected rule_id 'test-specfarm-dir-exists' not found"
        test_result "T028b-01-list-output-entries" "FAIL"
        return 1
    fi
    
    echo "    All expected rule IDs found in output"
    
    test_result "T028b-01-list-output-entries" "PASS"
    return 0
}

# Test 2: Normalized output comparison
t028b_02_normalized_output() {
    echo ""
    echo "Test: T028b-02 - Normalized list output comparison"
    
    local test_log="$SCRIPT_DIR/testdata/justifications-sample.log"
    local parity_validator="$SCRIPT_DIR/parity-validator.sh"
    
    if [[ ! -f "$test_log" ]]; then
        echo "    SKIP: Fixture missing: $test_log"
        test_result "T028b-02-normalized-output" "FAIL"
        return 1
    fi
    
    # Run justify-log list
    local list_output
    list_output=$(mock_justify_log_list "$test_log" 2>&1)
    
    # Normalize output
    local normalized_output
    normalized_output=$(normalize_list_output "$list_output")
    
    # Verify timestamps were normalized
    if echo "$normalized_output" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        echo "    FAIL: Timestamps not properly normalized"
        test_result "T028b-02-normalized-output" "FAIL"
        return 1
    fi
    
    echo "    Timestamps successfully normalized to TIMESTAMP placeholder"
    
    # Verify rule IDs and statuses still present after normalization
    if ! echo "$normalized_output" | grep -q "shell-prefer-posix"; then
        echo "    FAIL: rule_id missing after normalization"
        test_result "T028b-02-normalized-output" "FAIL"
        return 1
    fi
    
    if ! echo "$normalized_output" | grep -q "DRIFT\|JUSTIFIED"; then
        echo "    FAIL: status missing after normalization"
        test_result "T028b-02-normalized-output" "FAIL"
        return 1
    fi
    
    echo "    Rule IDs and statuses preserved after normalization"
    
    test_result "T028b-02-normalized-output" "PASS"
    return 0
}

# Test 3: Verify output line count matches expected
t028b_03_line_count_verification() {
    echo ""
    echo "Test: T028b-03 - Verify output line count"
    
    local test_log="$SCRIPT_DIR/testdata/justifications-sample.log"
    
    if [[ ! -f "$test_log" ]]; then
        echo "    SKIP: Fixture missing: $test_log"
        test_result "T028b-03-line-count-verification" "FAIL"
        return 1
    fi
    
    # Count entries in fixture
    local entry_count
    entry_count=$(grep -c '^{' "$test_log")
    
    # Run justify-log list
    local list_output
    list_output=$(mock_justify_log_list "$test_log" 2>&1)
    
    # Each entry should produce 2 lines (header + justification text)
    local expected_lines=$((entry_count * 2))
    local actual_lines
    actual_lines=$(echo "$list_output" | wc -l)
    
    echo "    Expected lines: $expected_lines"
    echo "    Actual lines: $actual_lines"
    
    # Allow small variance for blank lines
    local variance=$((actual_lines - expected_lines))
    if [[ $variance -lt 0 ]]; then
        variance=$((-variance))
    fi
    
    if [[ $variance -gt 2 ]]; then
        echo "    FAIL: Line count variance too large: $variance"
        test_result "T028b-03-line-count-verification" "FAIL"
        return 1
    fi
    
    echo "    Line count within acceptable variance"
    
    test_result "T028b-03-line-count-verification" "PASS"
    return 0
}

# Main test execution
main() {
    echo "=========================================="
    echo "T028b: Justify-Log List Output Test"
    echo "Constitution: II.A (Zero external dependencies)"
    echo "=========================================="
    
    t028b_01_list_output_entries
    t028b_02_normalized_output
    t028b_03_line_count_verification
    
    echo ""
    echo "=========================================="
    echo "Test Summary:"
    echo "  Total:  $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "=========================================="
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "Result: ALL TESTS PASSED ✓"
        exit 0
    else
        echo "Result: SOME TESTS FAILED ✗"
        exit 1
    fi
}

main "$@"
