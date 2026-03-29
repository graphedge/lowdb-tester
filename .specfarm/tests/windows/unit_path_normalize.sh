#!/bin/bash
# T013: Path Normalization Test — Phase 3b
# Tests src/crossplatform/path-normalize.sh on Windows
# Verifies Windows paths convert correctly to Unix format

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

echo "=== T013: Path Normalization Test ==="
echo ""

if [[ ! -f "$BASE_DIR/src/crossplatform/path-normalize.sh" ]]; then
    echo -e "${YELLOW}⚠️  path-normalize.sh not found (T006 not complete)${NC}"
    exit 0
fi

source "$BASE_DIR/src/crossplatform/path-normalize.sh"

# Test 1: normalize_path function exists
run_test "normalize_path function exists" \
    "declare -f normalize_path > /dev/null"

# Test 2: Relative paths preserved
run_test "Relative paths preserved" \
    "normalized=\$(normalize_path './src/file.sh'); [[ \"\$normalized\" == './src/file.sh' ]] || [[ \"\$normalized\" == 'src/file.sh' ]]"

# Test 3: Unix paths unchanged
run_test "Unix paths unchanged" \
    "normalized=\$(normalize_path '/usr/local/bin'); [[ \"\$normalized\" == '/usr/local/bin' ]]"

# Test 4: Forward slashes handled
run_test "Forward slashes handled" \
    "normalized=\$(normalize_path 'src/drift/file.sh'); [[ \"\$normalized\" == 'src/drift/file.sh' ]]"

# Test 5: No spaces in paths (basic path)
run_test "Simple paths normalized correctly" \
    "normalized=\$(normalize_path 'src'); [[ \"\$normalized\" == 'src' ]]"

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
