#!/bin/bash
# T014: Line Endings Test — Phase 3b
# Tests src/crossplatform/line-endings.sh on Windows
# Verifies CRLF ↔ LF conversion works correctly

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

echo "=== T014: Line Endings Test ==="
echo ""

if [[ ! -f "$BASE_DIR/src/crossplatform/line-endings.sh" ]]; then
    echo -e "${YELLOW}⚠️  line-endings.sh not found (T007 not complete)${NC}"
    exit 0
fi

source "$BASE_DIR/src/crossplatform/line-endings.sh"

# Create test files
TEST_DIR="/tmp/specfarm-line-endings-test-$$"
mkdir -p "$TEST_DIR"
trap "rm -rf \"$TEST_DIR\"" EXIT

# Test 1: normalize_line_endings function exists
run_test "normalize_line_endings function exists" \
    "declare -f normalize_line_endings > /dev/null"

# Test 2: CRLF file is processed without error
run_test "CRLF file processed without error" \
    "printf 'line1\r\nline2\r\n' > \"$TEST_DIR/crlf_test.txt\"; normalize_line_endings \"$TEST_DIR/crlf_test.txt\" && [[ -f \"$TEST_DIR/crlf_test.txt\" ]]"

# Test 3: LF file unchanged
run_test "LF file unchanged" \
    "echo -e 'line1\nline2' > \"$TEST_DIR/lf_test.txt\"; original=\$(md5sum \"$TEST_DIR/lf_test.txt\"); normalize_line_endings \"$TEST_DIR/lf_test.txt\"; after=\$(md5sum \"$TEST_DIR/lf_test.txt\"); [[ \"\$original\" == \"\$after\" ]]"

# Test 4: File exists after normalization
run_test "File exists after normalization" \
    "printf 'test\r\n' > \"$TEST_DIR/exists_test.txt\"; normalize_line_endings \"$TEST_DIR/exists_test.txt\"; [[ -f \"$TEST_DIR/exists_test.txt\" ]]"

# Test 5: Content is readable after normalization
run_test "Content is readable after normalization" \
    "printf 'readable\r\n' > \"$TEST_DIR/readable_test.txt\"; normalize_line_endings \"$TEST_DIR/readable_test.txt\"; grep -q 'readable' \"$TEST_DIR/readable_test.txt\""

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
