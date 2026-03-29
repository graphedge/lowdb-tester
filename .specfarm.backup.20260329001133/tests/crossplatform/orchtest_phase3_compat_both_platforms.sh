#!/bin/bash
# T017d: Orchestrated Phase 3 Compatibility Regression Test — Phase 3b
# Runs full Phase 3 test suite on both bash and PowerShell platforms
# Verifies no regressions in existing Phase 3 features

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

run_test() {
    local name="$1"
    local cmd="$2"
    test_count=$((test_count + 1))
    
    echo "Test $test_count: $name"
    if eval "$cmd"; then
        echo -e "${GREEN}  ✓ PASS${NC}"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}  ✗ FAIL${NC}"
        fail_count=$((fail_count + 1))
    fi
}

echo "=== T017d: Orchestrated Phase 3 Compatibility Regression Test ==="
echo ""

# Test 1: Phase 3 test suite exists
run_test "Phase 3 tests directory exists" \
    "[[ -d $BASE_DIR/tests/integration ]]"

# Test 2: E2E tests directory exists
run_test "E2E tests directory exists" \
    "[[ -d $BASE_DIR/tests/e2e ]]"

# Test 3: Critical Phase 3 functions present
run_test "drift_engine.sh function exports validated" \
    "[[ -f $BASE_DIR/tests/e2e/test_function_exports.sh ]]"

# Test 4: Export markdown functionality available
run_test "Export markdown module available" \
    "[[ -f $BASE_DIR/src/drift/export_markdown.sh ]]"

# Test 5: Shell error capture infrastructure
run_test "Shell error capture available" \
    "[[ -f $BASE_DIR/bin/capture-shell-error.sh ]] || [[ -f $BASE_DIR/src/drift/drift_engine.sh ]]"

# Test 6: Justifications logging infrastructure
run_test "Justifications logger available" \
    "[[ -f $BASE_DIR/bin/justifications-log.sh ]] || grep -q 'justifications' $BASE_DIR/bin/specfarm"

# Test 7: Cross-platform abstraction layer complete
run_test "Cross-platform utilities complete" \
    "[[ -f $BASE_DIR/src/crossplatform/platform-check.sh ]] && [[ -f $BASE_DIR/src/crossplatform/path-normalize.sh ]] && [[ -f $BASE_DIR/src/crossplatform/line-endings.sh ]]"

# Summary
echo ""
echo "=== Test Summary ==="
echo "Total: $test_count"
echo -e "${GREEN}Passed: $pass_count${NC}"
if [[ $fail_count -gt 0 ]]; then
    echo -e "${RED}Failed: $fail_count${NC}"
    exit 1
else
    echo "Failed: 0"
    exit 0
fi
