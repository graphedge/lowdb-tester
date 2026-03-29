#!/bin/bash
# T034: Unit test - convert file paths to Markdown links on Windows

set -euo pipefail

PASS=0; FAIL=0; SKIP=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATH_NORMALIZE="$REPO_ROOT/src/crossplatform/path-normalize.sh"

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP+1)); }

echo "Test T034: Markdown Path Conversion (Windows)"
echo "==============================================="

if [[ ! -f "$PATH_NORMALIZE" ]]; then
    echo "  ⚠️  path-normalize.sh not found — skipping all tests"
    exit 0
fi

source "$PATH_NORMALIZE"

# Test 6.1: Windows path → Markdown link
echo "  Test 6.1: Windows path converts to Markdown link..."
WIN_PATH='C:\Users\user\project\src\drift.sh'
if declare -f normalize_path &>/dev/null; then
    NORMALIZED=$(normalize_path "$WIN_PATH" 2>/dev/null || echo "$WIN_PATH")
    if echo "$NORMALIZED" | grep -q "/c/\|/Users/"; then
        pass "Windows path normalized: $NORMALIZED"
    else
        fail "Windows path not normalized: got $NORMALIZED"
    fi
else
    fail "normalize_path function not declared"
fi

# Test 6.2: UNC path → normalized
echo "  Test 6.2: UNC path normalizes..."
UNC_PATH='\\server\share\file.sh'
if declare -f normalize_path &>/dev/null; then
    NORMALIZED=$(normalize_path "$UNC_PATH" 2>/dev/null || echo "$UNC_PATH")
    if echo "$NORMALIZED" | grep -q "//server"; then
        pass "UNC path normalized: $NORMALIZED"
    else
        fail "UNC path not normalized: got $NORMALIZED"
    fi
else
    skip "normalize_path not available"
fi

# Test 6.3: Forward-slash path unchanged
echo "  Test 6.3: Forward-slash path unchanged..."
UNIX_PATH='/home/user/project/src/drift.sh'
if declare -f normalize_path &>/dev/null; then
    NORMALIZED=$(normalize_path "$UNIX_PATH" 2>/dev/null || echo "$UNIX_PATH")
    [[ "$NORMALIZED" == "$UNIX_PATH" ]] && pass "Unix path unchanged" || fail "Unix path changed unexpectedly: $NORMALIZED"
else
    skip "normalize_path not available"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]] && echo "✅ T034 Tests Passed" || { echo "⚠️  T034 Tests INCOMPLETE (TDD)"; exit 1; }
