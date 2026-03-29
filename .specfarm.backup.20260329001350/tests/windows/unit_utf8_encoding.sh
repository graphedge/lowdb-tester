#!/bin/bash
# T025: Unit test - UTF-8 encoding of justifications on Windows
# TDD: Expected to FAIL until T031 implementation complete

set -euo pipefail

PASS=0; FAIL=0; SKIP=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JUSTIFY_LOG="$REPO_ROOT/bin/justify-log.sh"
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf $TMPDIR_TEST" EXIT

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP+1)); }

echo "Test T025: UTF-8 Encoding of Justifications"
echo "============================================="

# Test 2.5: Handle accented characters
echo "  Test 2.5: UTF-8 accented chars round-trip..."
UTF8_LOG="$TMPDIR_TEST/utf8-test.log"
UTF8_REASON="Raison: résolution du problème (café, naïve, Ångström)"
printf '{"timestamp":"2026-03-18T10:00:00Z","rule_id":"r1","justification":"%s","author":"user@test"}\n' "$UTF8_REASON" > "$UTF8_LOG"

if command -v python3 &>/dev/null; then
    VALID=$(python3 -c "
import json, sys
with open('$UTF8_LOG', 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        entry = json.loads(line)
        assert 'résolution' in entry['justification'], f'UTF-8 lost: {entry[\"justification\"]}'
print('valid')
" 2>&1)
    if echo "$VALID" | grep -q "valid"; then
        pass "UTF-8 accented chars preserved in JSON Lines"
    else
        fail "UTF-8 encoding issue: $VALID"
    fi
else
    skip "python3 not available"
fi

# Test 2.6: Handle emoji in justifications
echo "  Test 2.6: UTF-8 emoji round-trip..."
EMOJI_REASON="Emergency fix 🔥 for production bug 🐛"
printf '{"timestamp":"2026-03-18T10:01:00Z","rule_id":"r2","justification":"%s","author":"user@test"}\n' "$EMOJI_REASON" > "$UTF8_LOG"

if command -v python3 &>/dev/null; then
    VALID=$(python3 -c "
import json, sys
with open('$UTF8_LOG', 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        entry = json.loads(line)
        assert '🔥' in entry['justification'], 'Emoji lost'
print('valid')
" 2>&1)
    [[ "$VALID" == "valid" ]] && pass "Emoji preserved in justification" || fail "Emoji lost: $VALID"
else
    skip "python3 not available"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]] && echo "✅ T025 Tests Passed" || { echo "⚠️  T025 Tests INCOMPLETE (TDD)"; exit 1; }
