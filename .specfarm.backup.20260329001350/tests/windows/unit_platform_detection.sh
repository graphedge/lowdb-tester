#!/bin/bash
# T012: Platform Detection Test — Phase 3b
# Tests src/crossplatform/platform-check.sh on Windows
# Should detect Windows OS and PowerShell version correctly

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_count=0
pass_count=0
fail_count=0

# Helper: run test
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

echo "=== T012: Platform Detection Test ==="
echo ""

# Check that platform-check.sh exists
if [[ ! -f "$BASE_DIR/src/crossplatform/platform-check.sh" ]]; then
    echo -e "${YELLOW}⚠️  platform-check.sh not found (T005 not complete)${NC}"
    exit 0
fi

# Source the platform check module
source "$BASE_DIR/src/crossplatform/platform-check.sh"

# Test 1: detect_platform function exists
run_test "detect_platform function exists" \
    "declare -f detect_platform > /dev/null"

# Test 2: Platform detection returns a value
run_test "Platform detection returns a value" \
    "[[ -n \$(detect_platform) ]]"

# Test 3: Platform detection returns known platform
run_test "Platform detection returns known platform" \
    "platform=\$(detect_platform); [[ \"\$platform\" =~ ^(windows|linux|macos|unknown)$ ]]"

# Test 4: PowerShell detection on Windows
if [[ $(detect_platform) == "windows" ]]; then
    run_test "PowerShell is available on Windows" \
        "command -v pwsh &>/dev/null || command -v powershell &>/dev/null"
    
    run_test "PowerShell version can be detected" \
        "ps_version=\$(pwsh -NoProfile -Command '\$PSVersionTable.PSVersion.Major' 2>/dev/null || echo '0'); [[ \$ps_version -ge 5 ]]"
fi

# Test 5: Bash detection
run_test "Bash is available" \
    "command -v bash > /dev/null"

# Test 6: Git detection
run_test "Git is available" \
    "command -v git > /dev/null"

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
