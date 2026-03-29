#!/usr/bin/env bash
# T027 [P] [US3] Integration test: run specfarm stub new --type payroll and verify files created
set -euo pipefail

# Test harness setup
TEST_NAME="test_stub_generation"
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

# Setup: Create temporary test directory
TEST_DIR="$PROJECT_ROOT/specseeds/test-payroll-$$"
trap "rm -rf '$TEST_DIR'" EXIT

# Test 1: Run specfarm stub new --type payroll
cd "$PROJECT_ROOT"
if .specfarm/bin/specfarm-stub new --type payroll --name test-payroll-$$ 2>&1; then
    pass "specfarm stub command executed successfully"
    EXIT_CODE=0
else
    EXIT_CODE=$?
    fail "specfarm stub command failed with exit code $EXIT_CODE"
fi

# Test 2: Verify spec.md was created
if [[ -f "$TEST_DIR/spec.md" ]]; then
    pass "spec.md file created in specseeds/test-payroll-$$/"
else
    fail "spec.md not found in specseeds/test-payroll-$$/"
fi

# Test 3: Verify plan.md was created
if [[ -f "$TEST_DIR/plan.md" ]]; then
    pass "plan.md file created in specseeds/test-payroll-$$/"
else
    fail "plan.md not found in specseeds/test-payroll-$$/"
fi

# Test 4: Verify variable substitution occurred ({{NAME}} should be replaced)
if [[ -f "$TEST_DIR/spec.md" ]]; then
    if grep -q "{{NAME}}" "$TEST_DIR/spec.md"; then
        fail "{{NAME}} placeholder not substituted in spec.md"
    else
        pass "{{NAME}} placeholder substituted in spec.md"
    fi
fi

# Test 5: Verify {{DATE}} placeholder was substituted
if [[ -f "$TEST_DIR/spec.md" ]]; then
    if grep -q "{{DATE}}" "$TEST_DIR/spec.md"; then
        fail "{{DATE}} placeholder not substituted in spec.md"
    else
        pass "{{DATE}} placeholder substituted in spec.md"
    fi
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
