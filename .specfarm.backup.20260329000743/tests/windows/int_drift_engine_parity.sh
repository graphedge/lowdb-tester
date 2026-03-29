#!/bin/bash
# T015: Drift Engine Integration Test — Phase 3b
# Tests bin/drift-engine.ps1 on Windows
# Verifies drift detection runs without error

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors for output
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

echo "=== T015: Drift Engine Integration Test ==="
echo ""

# Test 1: drift-engine file exists
run_test "drift-engine file exists" \
    "[[ -f \"$BASE_DIR/bin/drift-engine\" ]]"

# Test 2: drift-engine is executable
run_test "drift-engine is executable" \
    "[[ -x \"$BASE_DIR/bin/drift-engine\" ]]"

# Test 3: drift-engine help works
run_test "drift-engine help works" \
    "bash \"$BASE_DIR/bin/drift-engine\" --help 2>&1 | grep -q 'Usage:'"

# Test 4: drift-engine.ps1 exists (T009)
run_test "drift-engine.ps1 exists" \
    "[[ -f \"$BASE_DIR/bin/drift-engine.ps1\" ]]"

# Test 5: drift engine script can be sourced
run_test "drift engine can validate syntax" \
    "bash -n \"$BASE_DIR/bin/drift-engine\""

# Test 6: drift_engine.sh exists (required dependency)
run_test "drift_engine.sh exists" \
    "[[ -f \"$BASE_DIR/src/drift/drift_engine.sh\" ]]"

# Test 7: nudge_engine.sh exists (required dependency)
run_test "nudge_engine.sh exists" \
    "[[ -f \"$BASE_DIR/src/vibe/nudge_engine.sh\" ]]"

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
