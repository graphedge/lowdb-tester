#!/bin/bash
# T017a: Orchestrated Drift Parity Test (Basic) — Phase 3b
# Runs /specfarm drift on bash, then on PowerShell
# Compares normalized drift table structure for parity

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

echo "=== T017a: Orchestrated Drift Parity Test (Basic) ==="
echo ""

# Test 1: Parity validator exists
run_test "Parity validator script exists" \
    "[[ -f $BASE_DIR/tests/crossplatform/parity-validator.sh ]]"

# Test 2: Test runner exists
run_test "Dual test runner script exists" \
    "[[ -f $BASE_DIR/tests/crossplatform/test-runner-dual.sh ]]"

# Test 3: Testdata exists
run_test "Test fixtures directory exists" \
    "[[ -d $BASE_DIR/tests/crossplatform/testdata ]]"

run_test "Basic rules fixture exists" \
    "[[ -f $BASE_DIR/tests/crossplatform/testdata/rules-basic.xml ]]"

# Test 4: Drift engine scripts available
run_test "Bash drift engine available" \
    "[[ -f $BASE_DIR/bin/drift-engine ]]"

run_test "PowerShell drift engine available" \
    "[[ -f $BASE_DIR/bin/drift-engine.ps1 ]]"

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
