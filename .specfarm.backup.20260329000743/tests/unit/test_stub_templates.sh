#!/usr/bin/env bash
# T026 [P] [US3] Unit test: verify stub template loading and variable substitution
set -euo pipefail

# Test harness setup
TEST_NAME="test_stub_templates"
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

# Test 1: Verify specfarm-stub exists
if [[ -f "$PROJECT_ROOT/.specfarm/bin/specfarm-stub" ]]; then
    pass "specfarm-stub script exists"
else
    fail "specfarm-stub script not found at $PROJECT_ROOT/.specfarm/bin/specfarm-stub"
fi

# Test 2: Verify template directory structure exists
if [[ -d "$PROJECT_ROOT/specseeds/templates" ]]; then
    pass "templates directory exists"
else
    fail "templates directory not found at $PROJECT_ROOT/specseeds/templates"
fi

# Test 3: Verify at least one template type exists (payroll)
if [[ -d "$PROJECT_ROOT/specseeds/templates/payroll" ]]; then
    pass "payroll template directory exists"
else
    fail "payroll template directory not found"
fi

# Test 4: Verify template files have required placeholders
TEMPLATE_DIR="$PROJECT_ROOT/specseeds/templates/payroll"
if [[ -f "$TEMPLATE_DIR/spec.md" ]]; then
    if grep -q "{{NAME}}" "$TEMPLATE_DIR/spec.md" 2>/dev/null; then
        pass "template contains {{NAME}} placeholder"
    else
        fail "template missing {{NAME}} placeholder"
    fi
else
    fail "payroll spec.md template not found"
fi

# Test 5: Verify unknown template type returns error
if [[ -x "$PROJECT_ROOT/.specfarm/bin/specfarm-stub" ]]; then
    OUTPUT=$("$PROJECT_ROOT/.specfarm/bin/specfarm-stub" new --type nonexistent 2>&1 || true)
    if echo "$OUTPUT" | grep -qi "not found\|unknown\|error"; then
        pass "unknown template type returns error"
    else
        fail "unknown template type should return error message"
    fi
else
    fail "specfarm-stub not executable or not found"
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
