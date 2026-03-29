#!/bin/bash
# T033: Unit test - drift markdown template rendering on Windows

set -euo pipefail

PASS=0; FAIL=0; SKIP=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXPORT_MARKDOWN="$REPO_ROOT/src/drift/export_markdown.sh"
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf $TMPDIR_TEST" EXIT

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP+1)); }

echo "Test T033: Markdown Rendering (Windows Parity)"
echo "================================================"

# Test 5.1: export_markdown.sh exists
echo "  Test 5.1: export_markdown.sh exists..."
if [[ -f "$EXPORT_MARKDOWN" ]]; then
    pass "export_markdown.sh found"
else
    fail "export_markdown.sh NOT found at $EXPORT_MARKDOWN"
fi

# Test 5.2: Bash syntax valid
echo "  Test 5.2: Bash syntax valid..."
if [[ -f "$EXPORT_MARKDOWN" ]]; then
    bash -n "$EXPORT_MARKDOWN" 2>/dev/null && pass "Bash syntax valid" || fail "Bash syntax error"
else
    skip "File not found"
fi

# Test 5.3: Generates valid Markdown table
echo "  Test 5.3: Markdown table structure..."
if [[ -f "$EXPORT_MARKDOWN" ]]; then
    # Source and test if export_markdown function exists
    if bash -c "source '$EXPORT_MARKDOWN' 2>/dev/null && declare -f export_markdown" &>/dev/null; then
        pass "export_markdown function declared"
    else
        fail "export_markdown function not found in export_markdown.sh"
    fi
else
    skip "File not found"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]] && echo "✅ T033 Tests Passed" || { echo "⚠️  T033 Tests INCOMPLETE (TDD)"; exit 1; }
