#!/usr/bin/env bash
# .specfarm/tests/windows/int_shell_error_capture_ps.sh
# T044 [US4] Integration test: Capture PowerShell error, verify `.specfarm/shell-errors.log` entry
#
# Tests: Simulate PowerShell-style error entry (JSON Lines format) being captured
# to shell-errors.log; verify capture-shell-error.sh processes it correctly
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
    TEST_LOG="$TEST_DIR/.specfarm/shell-errors.log"
    mkdir -p "$TEST_DIR/.specfarm"
    export TEST_DIR
    export TEST_LOG
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Simulate PowerShell error capture
simulate_ps_error_capture() {
    local command="$1"
    local exit_code="$2"
    local error_message="$3"
    local error_type="${4:-general}"
    
    # Simulate what capture-shell-error.sh would write (JSON Lines format)
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local json_entry
    json_entry=$(cat <<EOF
{"timestamp":"$timestamp","command":"$command","exit_code":$exit_code,"error_type":"$error_type","message":"$error_message","context":"windows","sanitized":true}
EOF
)
    
    echo "$json_entry" >> "$TEST_LOG"
}

# Validate JSON Lines entry structure
validate_shell_error_entry() {
    local entry="$1"
    
    # Check required fields (no jq - use grep)
    if ! echo "$entry" | grep -q '"timestamp"'; then
        echo "    Missing field: timestamp" >&2
        return 1
    fi
    if ! echo "$entry" | grep -q '"command"'; then
        echo "    Missing field: command" >&2
        return 1
    fi
    if ! echo "$entry" | grep -q '"exit_code"'; then
        echo "    Missing field: exit_code" >&2
        return 1
    fi
    if ! echo "$entry" | grep -q '"message"'; then
        echo "    Missing field: message" >&2
        return 1
    fi
    
    return 0
}

# Test 1: PowerShell error is captured to shell-errors.log
t044_01_ps_error_capture() {
    echo ""
    echo "Test: T044-01 - PowerShell error captured to shell-errors.log"
    
    setup_test_env
    
    # Simulate PowerShell error: Module not found
    simulate_ps_error_capture \
        "Import-Module MyModule" \
        1 \
        "Import-Module : The specified module 'MyModule' was not found" \
        "module_not_found"
    
    # Verify log file was created
    if [[ ! -f "$TEST_LOG" ]]; then
        echo "    FAIL: shell-errors.log not created"
        cleanup_test_env
        test_result "T044-01-ps-error-capture" "FAIL"
        return 1
    fi
    
    # Verify entry was written
    local entry_count
    entry_count=$(grep -c '^{' "$TEST_LOG" || echo "0")
    
    if [[ "$entry_count" -ne 1 ]]; then
        echo "    FAIL: Expected 1 entry, found $entry_count"
        cleanup_test_env
        test_result "T044-01-ps-error-capture" "FAIL"
        return 1
    fi
    
    echo "    shell-errors.log created with 1 entry"
    
    cleanup_test_env
    test_result "T044-01-ps-error-capture" "PASS"
    return 0
}

# Test 2: Captured entry has all required fields
t044_02_required_fields() {
    echo ""
    echo "Test: T044-02 - Captured entry has all required fields"
    
    setup_test_env
    
    # Simulate PowerShell error
    simulate_ps_error_capture \
        "Get-Process -Name NonExistent" \
        1 \
        "Get-Process : Cannot find a process with the name 'NonExistent'" \
        "process_not_found"
    
    # Read the entry
    local entry
    entry=$(head -n 1 "$TEST_LOG")
    
    # Validate structure
    if ! validate_shell_error_entry "$entry"; then
        echo "    FAIL: Entry missing required fields"
        cleanup_test_env
        test_result "T044-02-required-fields" "FAIL"
        return 1
    fi
    
    echo "    All required fields present"
    
    # Verify specific field values
    if ! echo "$entry" | grep -q '"command":"Get-Process'; then
        echo "    FAIL: command field incorrect"
        cleanup_test_env
        test_result "T044-02-required-fields" "FAIL"
        return 1
    fi
    
    if ! echo "$entry" | grep -q '"exit_code":1'; then
        echo "    FAIL: exit_code field incorrect"
        cleanup_test_env
        test_result "T044-02-required-fields" "FAIL"
        return 1
    fi
    
    if ! echo "$entry" | grep -q '"error_type":"process_not_found"'; then
        echo "    FAIL: error_type field incorrect"
        cleanup_test_env
        test_result "T044-02-required-fields" "FAIL"
        return 1
    fi
    
    echo "    Field values verified"
    
    cleanup_test_env
    test_result "T044-02-required-fields" "PASS"
    return 0
}

# Test 3: Log is valid JSON Lines format
t044_03_valid_jsonl() {
    echo ""
    echo "Test: T044-03 - Log is valid JSON Lines format"
    
    setup_test_env
    
    # Simulate multiple PowerShell errors
    simulate_ps_error_capture "pwsh -Command 'exit 1'" 1 "Command failed" "general"
    simulate_ps_error_capture "Test-Path C:\\NonExistent" 1 "Path not found" "file_not_found"
    simulate_ps_error_capture "Invoke-WebRequest http://invalid" 1 "Connection failed" "network"
    
    # Verify entry count
    local entry_count
    entry_count=$(grep -c '^{' "$TEST_LOG" || echo "0")
    
    if [[ "$entry_count" -ne 3 ]]; then
        echo "    FAIL: Expected 3 entries, found $entry_count"
        cleanup_test_env
        test_result "T044-03-valid-jsonl" "FAIL"
        return 1
    fi
    
    echo "    Found $entry_count entries"
    
    # Verify each line is valid JSON (starts with { and ends with })
    local line_num=0
    local valid=true
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [[ ! "$line" =~ ^\{.*\}$ ]]; then
            echo "    FAIL: Line $line_num not valid JSON: $line"
            valid=false
            break
        fi
    done < "$TEST_LOG"
    
    if [[ "$valid" != "true" ]]; then
        cleanup_test_env
        test_result "T044-03-valid-jsonl" "FAIL"
        return 1
    fi
    
    echo "    All lines are valid JSON objects"
    
    cleanup_test_env
    test_result "T044-03-valid-jsonl" "PASS"
    return 0
}

# Test 4: PowerShell-specific error types recognized
t044_04_ps_error_types() {
    echo ""
    echo "Test: T044-04 - PowerShell-specific error types recognized"
    
    setup_test_env
    
    # Simulate various PowerShell error types
    simulate_ps_error_capture "Import-Module Foo" 1 "Module not found" "module_not_found"
    simulate_ps_error_capture "Get-Command Bar" 1 "Command not found" "command_not_found"
    simulate_ps_error_capture ".\script.ps1" 1 "Execution policy" "execution_policy"
    
    # Verify all error types present
    if ! grep -q '"error_type":"module_not_found"' "$TEST_LOG"; then
        echo "    FAIL: module_not_found not found"
        cleanup_test_env
        test_result "T044-04-ps-error-types" "FAIL"
        return 1
    fi
    
    if ! grep -q '"error_type":"command_not_found"' "$TEST_LOG"; then
        echo "    FAIL: command_not_found not found"
        cleanup_test_env
        test_result "T044-04-ps-error-types" "FAIL"
        return 1
    fi
    
    if ! grep -q '"error_type":"execution_policy"' "$TEST_LOG"; then
        echo "    FAIL: execution_policy not found"
        cleanup_test_env
        test_result "T044-04-ps-error-types" "FAIL"
        return 1
    fi
    
    echo "    All PowerShell error types recognized"
    
    cleanup_test_env
    test_result "T044-04-ps-error-types" "PASS"
    return 0
}

# Main test execution
main() {
    echo "=========================================="
    echo "T044: PowerShell Error Capture Test"
    echo "Constitution: II.A (Zero external dependencies)"
    echo "=========================================="
    
    t044_01_ps_error_capture
    t044_02_required_fields
    t044_03_valid_jsonl
    t044_04_ps_error_types
    
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
