#!/usr/bin/env bash
# T029 [US3] End-to-end test: full stub + cross-check workflow
set -euo pipefail

# Test harness setup
TEST_NAME="test_stub_crosscheck_workflow"
PASSED=0
FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Helper functions
pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "=== Running $TEST_NAME ==="

# Setup: Use unique name for this test
TEST_NAME_ID="e2e-workflow-$$"
TEST_SEED_DIR="$PROJECT_ROOT/specseeds/$TEST_NAME_ID"
trap "rm -rf '$TEST_SEED_DIR'" EXIT

# Test 1: Create stub with specfarm-stub
cd "$PROJECT_ROOT"
if .specfarm/bin/specfarm-stub new --type payroll --name "$TEST_NAME_ID" 2>&1; then
    pass "stub generation completed"
else
    fail "stub generation failed"
fi

# Test 2: Verify stub was created
if [[ -d "$TEST_SEED_DIR" ]]; then
    pass "stub directory created"
else
    fail "stub directory not found"
fi

# Test 3: Run crosscheck on generated stub
if [[ -f "$PROJECT_ROOT/.specfarm/src/crosscheck/run_checks.sh" ]]; then
    if OUTPUT=$(.specfarm/src/crosscheck/run_checks.sh --specseed "$TEST_SEED_DIR" 2>&1); then
        pass "crosscheck executed on generated stub"
        
        # Test 4: Verify crosscheck report was generated
        if [[ -f "$TEST_SEED_DIR/crosscheck-report.txt" ]]; then
            pass "crosscheck report generated in stub directory"
        else
            fail "crosscheck report not found"
        fi
        
        # Test 5: Verify report contains expected content
        if grep -q "SCORE:" "$TEST_SEED_DIR/crosscheck-report.txt" 2>/dev/null; then
            pass "crosscheck report contains SCORE"
        else
            fail "crosscheck report missing SCORE line"
        fi
    else
        fail "crosscheck execution failed"
    fi
else
    fail "run_checks.sh not found"
fi

# Test 6: Verify end-to-end workflow completed successfully
if [[ -f "$TEST_SEED_DIR/spec.md" ]] && \
   [[ -f "$TEST_SEED_DIR/plan.md" ]] && \
   [[ -f "$TEST_SEED_DIR/crosscheck-report.txt" ]]; then
    pass "complete workflow: stub created and crosscheck report generated"
else
    fail "workflow incomplete: missing expected files"
fi

# Summary
echo ""
echo "=== Test Summary: $TEST_NAME ==="
echo "PASSED: $PASSED"
echo "FAILED: $FAILED"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
