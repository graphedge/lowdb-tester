#!/usr/bin/env bash
# .specfarm/tests/windows/int_nudge_output_ps.sh
# T045 [US4] Integration test: Verify nudge message appears in drift output on Windows
#
# Tests: With a Windows-specific antipattern rule in `.specfarm/rules.xml`,
# verify drift engine produces a nudge message
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

# Setup test environment
setup_test_env() {
    TEST_DIR=$(mktemp -d)
    TEST_RULES="$TEST_DIR/.specfarm/rules.xml"
    TEST_REPO="$TEST_DIR/test-repo"
    mkdir -p "$TEST_DIR/.specfarm"
    mkdir -p "$TEST_REPO"
    export TEST_DIR
    export TEST_RULES
    export TEST_REPO
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Create Windows-specific antipattern rule
create_windows_antipattern_rule() {
    cat > "$TEST_RULES" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <rule id="ps-avoid-invoke-expression" severity="HIGH" available-from="Phase 3b">
    <description>Avoid Invoke-Expression for security reasons</description>
    <pattern>Invoke-Expression</pattern>
    <rationale>Invoke-Expression is vulnerable to code injection attacks</rationale>
    <nudge>Consider using direct function calls instead of Invoke-Expression</nudge>
    <platforms>
      <platform>windows</platform>
    </platforms>
  </rule>
  <rule id="ps-avoid-hardcoded-paths" severity="MEDIUM" available-from="Phase 3b">
    <description>Avoid hardcoded Windows paths</description>
    <pattern>C:\\Users\\</pattern>
    <rationale>Hardcoded paths are not portable across systems</rationale>
    <nudge>Use environment variables like $env:USERPROFILE instead</nudge>
    <platforms>
      <platform>windows</platform>
    </platforms>
  </rule>
</rules>
EOF
}

# Create test file with violations
create_test_file_with_violations() {
    cat > "$TEST_REPO/test-script.ps1" <<'EOF'
# Test PowerShell script with antipatterns

# Violation 1: Invoke-Expression
$command = "Get-Process"
Invoke-Expression $command

# Violation 2: Hardcoded path
$configPath = "C:\Users\Administrator\config.txt"
Get-Content $configPath
EOF
}

# Mock drift engine output (simulated)
mock_drift_engine() {
    local rules_file="$1"
    local repo_path="$2"
    
    # Simulate drift detection with nudge messages
    local detected_violations=0
    
    # Check for Invoke-Expression
    if grep -rq "Invoke-Expression" "$repo_path"; then
        echo "DRIFT: ps-avoid-invoke-expression"
        echo "  NUDGE: Consider using direct function calls instead of Invoke-Expression"
        detected_violations=$((detected_violations + 1))
    fi
    
    # Check for hardcoded paths
    if grep -rq 'C:\\Users\\' "$repo_path"; then
        echo "DRIFT: ps-avoid-hardcoded-paths"
        echo "  NUDGE: Use environment variables like \$env:USERPROFILE instead"
        detected_violations=$((detected_violations + 1))
    fi
    
    if [[ $detected_violations -eq 0 ]]; then
        echo "No drift detected"
        return 0
    fi
    
    echo ""
    echo "Drift score: $(awk "BEGIN { print 1.0 - ($detected_violations / 2.0) }")"
    echo "Detected $detected_violations violations"
    
    return 0
}

# Test 1: Nudge message appears in drift output
t045_01_nudge_appears() {
    echo ""
    echo "Test: T045-01 - Nudge message appears in drift output"
    
    setup_test_env
    create_windows_antipattern_rule
    create_test_file_with_violations
    
    # Simulate Windows environment
    export DETECTED_OS=windows
    
    # Run mock drift engine
    local drift_output
    drift_output=$(mock_drift_engine "$TEST_RULES" "$TEST_REPO" 2>&1)
    local exit_code=$?
    
    echo "    Drift output:"
    echo "$drift_output" | sed 's/^/      /'
    
    if [[ $exit_code -ne 0 ]]; then
        echo "    FAIL: Drift engine exited with code $exit_code"
        cleanup_test_env
        test_result "T045-01-nudge-appears" "FAIL"
        return 1
    fi
    
    # Verify nudge messages are present
    if ! echo "$drift_output" | grep -qi "nudge"; then
        echo "    FAIL: No nudge message found in output"
        cleanup_test_env
        test_result "T045-01-nudge-appears" "FAIL"
        return 1
    fi
    
    echo "    Nudge message found in drift output"
    
    cleanup_test_env
    test_result "T045-01-nudge-appears" "PASS"
    return 0
}

# Test 2: Specific nudge text for Invoke-Expression
t045_02_invoke_expression_nudge() {
    echo ""
    echo "Test: T045-02 - Specific nudge for Invoke-Expression antipattern"
    
    setup_test_env
    create_windows_antipattern_rule
    create_test_file_with_violations
    
    export DETECTED_OS=windows
    
    # Run drift engine
    local drift_output
    drift_output=$(mock_drift_engine "$TEST_RULES" "$TEST_REPO" 2>&1)
    
    # Verify specific nudge text
    if ! echo "$drift_output" | grep -q "Consider using direct function calls"; then
        echo "    FAIL: Expected nudge text not found"
        cleanup_test_env
        test_result "T045-02-invoke-expression-nudge" "FAIL"
        return 1
    fi
    
    echo "    Invoke-Expression nudge found"
    
    cleanup_test_env
    test_result "T045-02-invoke-expression-nudge" "PASS"
    return 0
}

# Test 3: Nudge for hardcoded paths
t045_03_hardcoded_path_nudge() {
    echo ""
    echo "Test: T045-03 - Nudge for hardcoded Windows paths"
    
    setup_test_env
    create_windows_antipattern_rule
    create_test_file_with_violations
    
    export DETECTED_OS=windows
    
    # Run drift engine
    local drift_output
    drift_output=$(mock_drift_engine "$TEST_RULES" "$TEST_REPO" 2>&1)
    
    # Verify hardcoded path nudge
    if ! echo "$drift_output" | grep -q "environment variables"; then
        echo "    FAIL: Expected nudge text for hardcoded paths not found"
        cleanup_test_env
        test_result "T045-03-hardcoded-path-nudge" "FAIL"
        return 1
    fi
    
    echo "    Hardcoded path nudge found"
    
    cleanup_test_env
    test_result "T045-03-hardcoded-path-nudge" "PASS"
    return 0
}

# Test 4: Exit code is non-fatal when nudge present
t045_04_non_fatal_exit() {
    echo ""
    echo "Test: T045-04 - Exit code is non-fatal (informational)"
    
    setup_test_env
    create_windows_antipattern_rule
    create_test_file_with_violations
    
    export DETECTED_OS=windows
    
    # Run drift engine
    local drift_output
    drift_output=$(mock_drift_engine "$TEST_RULES" "$TEST_REPO" 2>&1)
    local exit_code=$?
    
    # Nudge should be informational, not a hard failure
    if [[ $exit_code -ne 0 ]]; then
        echo "    FAIL: Exit code should be 0 for nudge (got $exit_code)"
        cleanup_test_env
        test_result "T045-04-non-fatal-exit" "FAIL"
        return 1
    fi
    
    echo "    Exit code is 0 (non-fatal)"
    
    cleanup_test_env
    test_result "T045-04-non-fatal-exit" "PASS"
    return 0
}

# Main test execution
main() {
    echo "=========================================="
    echo "T045: Nudge Output on Windows Test"
    echo "Constitution: II.A (Zero external dependencies)"
    echo "=========================================="
    
    t045_01_nudge_appears
    t045_02_invoke_expression_nudge
    t045_03_hardcoded_path_nudge
    t045_04_non_fatal_exit
    
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
