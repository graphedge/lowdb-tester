#!/bin/bash
# T028: E2E test - full justification workflow on Windows (drift → justify → log → commit)

set -euo pipefail

PASS=0; FAIL=0; SKIP=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf $TMPDIR_TEST" EXIT

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP+1)); }

echo "Test T028: E2E Justification Workflow (Windows)"
echo "================================================="

# E2E 1: Simulate drift violation → log justification
echo "  E2E 1: Simulate drift → justify flow..."
JUST_LOG="$TMPDIR_TEST/justifications.log"
JUSTIFY="$REPO_ROOT/bin/justify-log.sh"

if [[ ! -f "$JUSTIFY" ]]; then
    skip "justify-log.sh not found"
else
    # Add justification for simulated violation
    echo "Production emergency fix" | JUSTIFICATIONS_LOG="$JUST_LOG" bash "$JUSTIFY" add "r1" 2>&1 || true
    
    if [[ -f "$JUST_LOG" ]]; then
        pass "Justification logged for drift violation"
    else
        fail "Justification log not created"
    fi
fi

# E2E 2: Log has correct structure for git tracking
echo "  E2E 2: Log suitable for git tracking (LF line endings)..."
if [[ -f "$JUST_LOG" ]]; then
    if command -v file &>/dev/null; then
        FILE_TYPE=$(file "$JUST_LOG")
        if echo "$FILE_TYPE" | grep -q "CRLF\|Windows"; then
            fail "Log has CRLF line endings — not git-friendly (T031 needed)"
        else
            pass "Log has LF line endings (git-trackable)"
        fi
    else
        skip "file command not available"
    fi
fi

# E2E 3: Log is valid JSON Lines (Python check)
echo "  E2E 3: Log is valid JSON Lines..."
if [[ -f "$JUST_LOG" ]] && command -v python3 &>/dev/null; then
    python3 -c "
import json
with open('$JUST_LOG') as f:
    count = 0
    for line in f:
        line = line.strip()
        if not line: continue
        json.loads(line)
        count += 1
print(f'{count} valid entries')
" 2>&1 && pass "JSON Lines valid" || fail "JSON Lines invalid"
else
    skip "python3 not available or log not created"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]] && echo "✅ T028 E2E Tests Passed" || { echo "⚠️  T028 Tests INCOMPLETE (TDD)"; exit 1; }
