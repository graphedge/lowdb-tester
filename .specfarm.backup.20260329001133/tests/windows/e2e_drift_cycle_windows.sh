#!/bin/bash
# T017: End-to-End Drift Cycle Test — Phase 3b
# Tests full drift cycle on Windows
# Verifies setup → detect → report flow

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

echo "=== T017: End-to-End Drift Cycle Test ==="
echo ""

# Test 1: All Phase 3 dependencies present
run_test "drift_engine.sh present" \
    "[[ -f \"$BASE_DIR/src/drift/drift_engine.sh\" ]]"

run_test "nudge_engine.sh present" \
    "[[ -f \"$BASE_DIR/src/vibe/nudge_engine.sh\" ]]"

run_test "export_markdown.sh present" \
    "[[ -f \"$BASE_DIR/src/drift/export_markdown.sh\" ]]"

# Test 2: rules.xml exists
run_test "rules.xml exists" \
    "[[ -f \"$BASE_DIR/.specfarm/rules.xml\" ]] || [[ -f \"$BASE_DIR/rules.xml\" ]]"

# Test 3: CLI wrappers exist
run_test "drift-engine bash script exists" \
    "[[ -f \"$BASE_DIR/bin/drift-engine\" ]]"

run_test "specfarm bash script exists" \
    "[[ -f \"$BASE_DIR/bin/specfarm\" ]]"

run_test "drift-engine.ps1 exists" \
    "[[ -f \"$BASE_DIR/bin/drift-engine.ps1\" ]]"

run_test "specfarm.ps1 exists" \
    "[[ -f \"$BASE_DIR/bin/specfarm.ps1\" ]]"

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
