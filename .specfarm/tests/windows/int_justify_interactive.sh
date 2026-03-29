#!/bin/bash
# T026: Integration test - capture justification via interactive prompt on Windows
# TDD: Expected to partially FAIL until T030 implementation complete (PowerShell prompt)

set -euo pipefail

PASS=0; FAIL=0; SKIP=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf $TMPDIR_TEST" EXIT

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP+1)); }

echo "Test T026: Interactive Justification Capture (Windows)"
echo "======================================================="

JUST_LOG="$TMPDIR_TEST/justifications.log"

# Test 3.1: Non-interactive justify (piped input)
echo "  Test 3.1: Justify via piped input (non-interactive)..."
if [[ -f "$REPO_ROOT/bin/justify-log.sh" ]]; then
    echo "Test justification via pipe" | JUSTIFICATIONS_LOG="$JUST_LOG" bash "$REPO_ROOT/bin/justify-log.sh" add "r1" 2>&1
    if [[ -f "$JUST_LOG" ]]; then
        pass "Justification log created"
    else
        fail "Justification log not created"
    fi
else
    skip "justify-log.sh not found"
fi

# Test 3.2: Verify log entry is valid JSON
echo "  Test 3.2: Log entry is valid JSON Lines..."
if [[ -f "$JUST_LOG" ]] && command -v python3 &>/dev/null; then
    VALID=$(python3 -c "
import json
with open('$JUST_LOG') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        json.loads(line)  # raises if invalid
print('valid')
" 2>&1)
    [[ "$VALID" == "valid" ]] && pass "JSON Lines valid" || fail "JSON Lines invalid: $VALID"
else
    skip "python3 not available or log not created"
fi

# Test 3.3: Log entry has required fields
echo "  Test 3.3: Required fields present..."
if [[ -f "$JUST_LOG" ]] && command -v python3 &>/dev/null; then
    FIELDS=$(python3 -c "
import json
with open('$JUST_LOG') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        entry = json.loads(line)
        required = ['timestamp', 'rule_id', 'justification']
        missing = [k for k in required if k not in entry]
        if missing:
            print(f'MISSING: {missing}')
        else:
            print('ok')
" 2>&1)
    [[ "$FIELDS" == "ok" ]] && pass "All required fields present" || fail "Fields check: $FIELDS"
else
    skip "python3 not available"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]] && echo "✅ T026 Tests Passed" || { echo "⚠️  T026 Tests INCOMPLETE (TDD)"; exit 1; }
