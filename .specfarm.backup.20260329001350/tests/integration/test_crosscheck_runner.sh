#!/usr/bin/env bash
# T028 [US3] Integration test: verify cross-check runner executes and produces a score report
set -euo pipefail

# Test harness setup
TEST_NAME="test_crosscheck_runner"
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

# Test 1: Verify run_checks.sh exists
if [[ -f "$PROJECT_ROOT/.specfarm/src/crosscheck/run_checks.sh" ]]; then
    pass "run_checks.sh exists"
else
    fail "run_checks.sh not found at $PROJECT_ROOT/.specfarm/src/crosscheck/run_checks.sh"
fi

# Setup: Create a test specseed directory
TEST_SEED_DIR="$PROJECT_ROOT/specseeds/test-crosscheck-$$"
mkdir -p "$TEST_SEED_DIR"
trap "rm -rf '$TEST_SEED_DIR'" EXIT

# Create a valid spec.md with required sections
cat > "$TEST_SEED_DIR/spec.md" <<'EOF'
# Test Feature

## Goals

This is a test feature to verify crosscheck functionality.

## Constraints

Must follow all testing guidelines and maintain compatibility.

This document has more than 50 words to pass the word count check.
We need to ensure adequate documentation coverage for all features.
EOF

# Test 2: Run run_checks.sh on valid specseed
cd "$PROJECT_ROOT"
if OUTPUT=$(.specfarm/src/crosscheck/run_checks.sh --specseed "$TEST_SEED_DIR" 2>&1); then
    pass "run_checks.sh executed successfully"
    
    # Test 3: Verify output contains SCORE
    if echo "$OUTPUT" | grep -q "SCORE:"; then
        pass "output contains SCORE:"
    else
        fail "output missing SCORE: line"
    fi
    
    # Test 4: Verify output contains PASS/FAIL indicators
    if echo "$OUTPUT" | grep -qE "PASS|FAIL"; then
        pass "output contains PASS/FAIL indicators"
    else
        fail "output missing PASS/FAIL indicators"
    fi
    
    # Test 5: Verify report file was created
    if [[ -f "$TEST_SEED_DIR/crosscheck-report.txt" ]]; then
        pass "crosscheck-report.txt created"
    else
        fail "crosscheck-report.txt not created"
    fi
else
    fail "run_checks.sh failed to execute"
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
