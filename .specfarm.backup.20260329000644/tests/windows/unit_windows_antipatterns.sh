#!/bin/bash
# T043: Unit test - Identify Windows-specific antipatterns

set -euo pipefail

PASS=0; FAIL=0; SKIP=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANTIPATTERNS_CONF="$REPO_ROOT/rules/nudges/windows-antipatterns.conf"

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP+1)); }

echo "Test T043: Windows Antipattern Detection"
echo "========================================="

# Test 8.1: antipatterns.conf exists
echo "  Test 8.1: windows-antipatterns.conf exists..."
if [[ -f "$ANTIPATTERNS_CONF" ]]; then
    pass "Found at $ANTIPATTERNS_CONF"
else
    fail "NOT found at $ANTIPATTERNS_CONF"
fi

if [[ ! -f "$ANTIPATTERNS_CONF" ]]; then
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

# Test 8.2: Has at least 6 patterns
echo "  Test 8.2: At least 6 patterns defined..."
PATTERN_COUNT=$(grep -c "^pattern=" "$ANTIPATTERNS_CONF" || echo 0)
if [[ "$PATTERN_COUNT" -ge 6 ]]; then
    pass "Found $PATTERN_COUNT patterns (≥6 required)"
else
    fail "Only $PATTERN_COUNT patterns found (need ≥6)"
fi

# Test 8.3: Hardcoded path pattern present
echo "  Test 8.3: Hardcoded C:\\ path pattern..."
if grep -q "C:\\\\" "$ANTIPATTERNS_CONF"; then
    pass "Hardcoded Windows path pattern present"
else
    fail "Hardcoded Windows path pattern NOT found"
fi

# Test 8.4: pip install pattern present
echo "  Test 8.4: pip install without version pattern..."
if grep -q "pip install" "$ANTIPATTERNS_CONF"; then
    pass "pip install pattern present"
else
    fail "pip install pattern NOT found"
fi

# Test 8.5: Each pattern has a nudge
echo "  Test 8.5: Each pattern has a nudge..."
PATTERNS=$(grep "^pattern=" "$ANTIPATTERNS_CONF" | wc -l)
NUDGES=$(grep "^nudge=" "$ANTIPATTERNS_CONF" | wc -l)
if [[ "$PATTERNS" -eq "$NUDGES" ]]; then
    pass "Pattern-nudge count matches ($PATTERNS/$NUDGES)"
else
    fail "Pattern-nudge mismatch: $PATTERNS patterns, $NUDGES nudges"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]] && echo "✅ T043 Tests Passed" || { echo "⚠️  T043 Tests INCOMPLETE (TDD)"; exit 1; }
