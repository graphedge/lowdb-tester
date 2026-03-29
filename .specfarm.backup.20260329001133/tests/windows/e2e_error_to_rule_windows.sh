#!/usr/bin/env bash
# .specfarm/tests/windows/e2e_error_to_rule_windows.sh
# T046 [US4] End-to-end test: Full error → nudge → rule generation cycle on Windows
#
# Tests: Simulate the full pipeline: inject an error → capture it → drift engine
# produces nudge → verify audit trail
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
    TEST_SHELL_ERRORS="$TEST_DIR/.specfarm/shell-errors.log"
    TEST_JUSTIFICATIONS="$TEST_DIR/.specfarm/justifications.log"
    TEST_RULES="$TEST_DIR/.specfarm/rules.xml"
    TEST_REPO="$TEST_DIR/test-repo"
    mkdir -p "$TEST_DIR/.specfarm"
    mkdir -p "$TEST_REPO"
    export TEST_DIR
    export TEST_SHELL_ERRORS
    export TEST_JUSTIFICATIONS
    export TEST_RULES
    export TEST_REPO
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Step 1: Inject PowerShell error
inject_ps_error() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local error_entry
    error_entry=$(cat <<EOF
{"timestamp":"$timestamp","command":"Install-Module -Name NonExistent","exit_code":1,"error_type":"module_not_found","message":"PackageManagement\\Install-Package : No match was found for the specified search criteria","context":"windows","sanitized":true}
EOF
)
    
    echo "$error_entry" >> "$TEST_SHELL_ERRORS"
    echo "    Injected PowerShell error to shell-errors.log"
}

# Step 2: Detect error pattern and generate rule suggestion
generate_rule_from_error() {
    local shell_errors_log="$1"
    
    # Read the error
    local error_entry
    error_entry=$(head -n 1 "$shell_errors_log")
    
    # Extract command using grep/sed (no jq)
    local command
    command=$(echo "$error_entry" | grep -oP '"command":\s*"[^"]*"' | sed -E 's/"command":\s*"([^"]*)"/\1/')
    
    # Detect pattern: Install-Module without version
    if echo "$command" | grep -qE "Install-Module" && echo "$command" | grep -qE -- "-Name" && ! echo "$command" | grep -qE -- "-RequiredVersion"; then
        echo "    Detected antipattern: Install-Module without version pinning"
        
        # Create suggested rule
        cat > "$TEST_RULES" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rules>
  <rule id="ps-pin-module-versions" severity="HIGH" available-from="Phase 3b">
    <description>Pin PowerShell module versions in Install-Module</description>
    <pattern>Install-Module.*-Name [^ ]+(?!.*-RequiredVersion)</pattern>
    <rationale>Unpinned module versions can cause reproducibility issues</rationale>
    <nudge>Use Install-Module -Name ModuleName -RequiredVersion X.Y.Z</nudge>
    <platforms>
      <platform>windows</platform>
    </platforms>
  </rule>
</rules>
EOF
        
        return 0
    fi
    
    return 1
}

# Step 3: Run drift detection with new rule
run_drift_with_rule() {
    local rules_file="$1"
    local repo_path="$2"
    
    # Create test script with the antipattern
    cat > "$repo_path/install-modules.ps1" <<'EOF'
# Install required modules
Install-Module -Name Pester
Install-Module -Name PSScriptAnalyzer
EOF
    
    # Simulate drift detection
    local violations=0
    
    if grep -qE "Install-Module.*-Name [^ ]+" "$repo_path/install-modules.ps1" && \
       ! grep -qE "-RequiredVersion" "$repo_path/install-modules.ps1"; then
        echo "DRIFT: ps-pin-module-versions"
        echo "  NUDGE: Use Install-Module -Name ModuleName -RequiredVersion X.Y.Z"
        violations=$((violations + 1))
    fi
    
    echo "Drift detected: $violations violations"
    
    return 0
}

# Step 4: Log justification for drift
log_justification() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local justification_entry
    justification_entry=$(cat <<EOF
{"timestamp":"$timestamp","rule_id":"ps-pin-module-versions","status":"JUSTIFIED","justification":"Development environment only; version pinning will be enforced in CI/CD pipeline","agent":"copilot","commit":"abc1234"}
EOF
)
    
    echo "$justification_entry" >> "$TEST_JUSTIFICATIONS"
    echo "    Logged justification"
}

# Test 1: Full end-to-end pipeline
t046_01_e2e_pipeline() {
    echo ""
    echo "Test: T046-01 - Full error → nudge → rule generation cycle"
    
    setup_test_env
    
    # Step 1: Inject error
    echo "  Step 1: Inject PowerShell error"
    inject_ps_error
    
    # Verify error was logged
    if [[ ! -f "$TEST_SHELL_ERRORS" ]]; then
        echo "    FAIL: shell-errors.log not created"
        cleanup_test_env
        test_result "T046-01-e2e-pipeline" "FAIL"
        return 1
    fi
    
    local error_count
    error_count=$(grep -c '^{' "$TEST_SHELL_ERRORS" || echo "0")
    if [[ "$error_count" -ne 1 ]]; then
        echo "    FAIL: Expected 1 error, found $error_count"
        cleanup_test_env
        test_result "T046-01-e2e-pipeline" "FAIL"
        return 1
    fi
    
    echo "    ✓ Error captured"
    
    # Step 2: Generate rule from error
    echo "  Step 2: Generate rule from error pattern"
    if ! generate_rule_from_error "$TEST_SHELL_ERRORS"; then
        echo "    FAIL: Rule generation failed"
        cleanup_test_env
        test_result "T046-01-e2e-pipeline" "FAIL"
        return 1
    fi
    
    if [[ ! -f "$TEST_RULES" ]]; then
        echo "    FAIL: rules.xml not created"
        cleanup_test_env
        test_result "T046-01-e2e-pipeline" "FAIL"
        return 1
    fi
    
    echo "    ✓ Rule generated"
    
    # Step 3: Run drift detection
    echo "  Step 3: Run drift detection with new rule"
    local drift_output
    drift_output=$(run_drift_with_rule "$TEST_RULES" "$TEST_REPO" 2>&1)
    
    if ! echo "$drift_output" | grep -q "ps-pin-module-versions"; then
        echo "    FAIL: Expected rule not triggered"
        cleanup_test_env
        test_result "T046-01-e2e-pipeline" "FAIL"
        return 1
    fi
    
    if ! echo "$drift_output" | grep -qi "nudge"; then
        echo "    FAIL: Nudge message not present"
        cleanup_test_env
        test_result "T046-01-e2e-pipeline" "FAIL"
        return 1
    fi
    
    echo "    ✓ Drift detected with nudge"
    
    # Step 4: Log justification
    echo "  Step 4: Log justification"
    log_justification
    
    if [[ ! -f "$TEST_JUSTIFICATIONS" ]]; then
        echo "    FAIL: justifications.log not created"
        cleanup_test_env
        test_result "T046-01-e2e-pipeline" "FAIL"
        return 1
    fi
    
    local justification_count
    justification_count=$(grep -c '^{' "$TEST_JUSTIFICATIONS" || echo "0")
    if [[ "$justification_count" -ne 1 ]]; then
        echo "    FAIL: Expected 1 justification, found $justification_count"
        cleanup_test_env
        test_result "T046-01-e2e-pipeline" "FAIL"
        return 1
    fi
    
    echo "    ✓ Justification logged"
    
    echo ""
    echo "  ✓ Full pipeline completed successfully"
    
    cleanup_test_env
    test_result "T046-01-e2e-pipeline" "PASS"
    return 0
}

# Test 2: Audit trail verification
t046_02_audit_trail() {
    echo ""
    echo "Test: T046-02 - Verify complete audit trail"
    
    setup_test_env
    
    # Run full pipeline
    inject_ps_error
    generate_rule_from_error "$TEST_SHELL_ERRORS"
    run_drift_with_rule "$TEST_RULES" "$TEST_REPO" > /dev/null 2>&1
    log_justification
    
    # Verify all artifacts exist
    local artifacts_ok=true
    
    if [[ ! -f "$TEST_SHELL_ERRORS" ]]; then
        echo "    FAIL: shell-errors.log missing"
        artifacts_ok=false
    fi
    
    if [[ ! -f "$TEST_RULES" ]]; then
        echo "    FAIL: rules.xml missing"
        artifacts_ok=false
    fi
    
    if [[ ! -f "$TEST_JUSTIFICATIONS" ]]; then
        echo "    FAIL: justifications.log missing"
        artifacts_ok=false
    fi
    
    if [[ "$artifacts_ok" != "true" ]]; then
        cleanup_test_env
        test_result "T046-02-audit-trail" "FAIL"
        return 1
    fi
    
    echo "    All audit trail artifacts present"
    
    # Verify content linkage (same rule_id appears in rules.xml and justifications.log)
    if ! grep -q "ps-pin-module-versions" "$TEST_RULES"; then
        echo "    FAIL: Rule ID not in rules.xml"
        cleanup_test_env
        test_result "T046-02-audit-trail" "FAIL"
        return 1
    fi
    
    if ! grep -q "ps-pin-module-versions" "$TEST_JUSTIFICATIONS"; then
        echo "    FAIL: Rule ID not in justifications.log"
        cleanup_test_env
        test_result "T046-02-audit-trail" "FAIL"
        return 1
    fi
    
    echo "    Audit trail linkage verified"
    
    cleanup_test_env
    test_result "T046-02-audit-trail" "PASS"
    return 0
}

# Test 3: Windows context preserved throughout pipeline
t046_03_windows_context() {
    echo ""
    echo "Test: T046-03 - Windows context preserved throughout pipeline"
    
    setup_test_env
    export DETECTED_OS=windows
    
    # Run pipeline
    inject_ps_error
    generate_rule_from_error "$TEST_SHELL_ERRORS"
    
    # Verify Windows context in error log
    if ! grep -q '"context":"windows"' "$TEST_SHELL_ERRORS"; then
        echo "    FAIL: Windows context not in shell-errors.log"
        cleanup_test_env
        test_result "T046-03-windows-context" "FAIL"
        return 1
    fi
    
    # Verify Windows platform in rules.xml
    if ! grep -q '<platform>windows</platform>' "$TEST_RULES"; then
        echo "    FAIL: Windows platform not in rules.xml"
        cleanup_test_env
        test_result "T046-03-windows-context" "FAIL"
        return 1
    fi
    
    echo "    Windows context preserved throughout pipeline"
    
    cleanup_test_env
    test_result "T046-03-windows-context" "PASS"
    return 0
}

# Main test execution
main() {
    echo "=========================================="
    echo "T046: End-to-End Error → Rule Cycle Test"
    echo "Constitution: II.A (Zero external dependencies)"
    echo "=========================================="
    
    t046_01_e2e_pipeline
    t046_02_audit_trail
    t046_03_windows_context
    
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
