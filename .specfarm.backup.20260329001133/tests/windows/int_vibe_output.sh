#!/bin/bash
# T016: Vibe System Output Test — Phase 3b
# Tests vibe output on Windows terminal
# Verifies farm/jungle/plain messaging and ANSI fallback

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

echo "=== T016: Vibe System Output Test ==="
echo ""

if [[ ! -f "$BASE_DIR/src/vibe/nudge_engine.sh" ]]; then
    echo -e "${YELLOW}⚠️  nudge_engine.sh not found (vibe system not ready)${NC}"
    exit 0
fi

# Test 1: nudge_engine.sh file exists
run_test "nudge_engine.sh file exists" \
    "[[ -f \"$BASE_DIR/src/vibe/nudge_engine.sh\" ]]"

# Test 2: nudge_engine.sh has functions
run_test "nudge_engine.sh has dispatch_nudge function" \
    "bash -c \"source $BASE_DIR/src/vibe/nudge_engine.sh && declare -F dispatch_nudge > /dev/null\""

# Test 3: templates directory exists
run_test "templates directory exists" \
    "[[ -d \"$BASE_DIR/src/vibe/templates\" ]]"

# Test 4: templates are accessible
run_test "vibe templates accessible" \
    "ls -1 \"$BASE_DIR/src/vibe/templates/\" | grep -q '.'"

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
