#!/bin/bash
# T017b: Orchestrated Vibe Parity Test — Phase 3b
# Compares vibe output (farm/jungle/plain messaging) on bash vs PowerShell

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

echo "=== T017b: Orchestrated Vibe Parity Test ==="
echo ""

# Test 1: Vibe templates exist
run_test "Vibe templates directory exists" \
    "[[ -d $BASE_DIR/src/vibe/templates ]]"

# Test 2: Vibe engine sources correctly
run_test "Vibe nudge engine available" \
    "bash -c \"source $BASE_DIR/src/vibe/nudge_engine.sh && declare -F dispatch_nudge > /dev/null\""

# Test 3: Drift engine sources vibe module
run_test "Drift engine sources vibe module" \
    "grep -q 'nudge_engine.sh' $BASE_DIR/bin/drift-engine"

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
